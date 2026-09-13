"""Create programming gate only after RTL text, board simulation and timing pass."""
from pathlib import Path
import hashlib, subprocess,sys,json,re
from reference import ROOT,HPM
from modes import MODES
out=ROOT/'build/psk'
hpm_names=set(re.findall(r'MODE\([^,]+,\s*"([^"]+)"',(HPM/'app/modem/psk_modes.c').read_text()))
assert {name for name,_,_ in MODES}==hpm_names-{'2x8PSK1200F'},'HPM mode coverage differs'
for variant in ['nominal','stress']:
    vector_dir=ROOT/('build/psk-stress' if variant=='stress' else 'build/psk-vectors')
    manifest=json.loads((vector_dir/'manifest.json').read_text())
    assert manifest['modes']==[list(m) for m in MODES]
    for path,digest in manifest['transmitter_sources'].items():
        assert hashlib.sha256((HPM/path).read_bytes()).hexdigest()==digest,'HPM transmitter changed after vectors'
    subprocess.run([sys.executable,str(ROOT/'scripts/psk/check_results.py'),f'build/psk/{variant}'],check=True)
    log=(out/variant/'simulation.log').read_text()
    assert 'PASS RTL waveform run completed' in log and not re.search(r'FAIL|ERROR:|FATAL',log)
    core_sources=[ROOT/'rtl/psk'/p for p in ['psk_receiver.v','psk_decode.v','psk_fec_beam.v',
        'nco_sine.v','sine_init.vh','rx_fir_coeff.vh','mfsk_bit_decoder.v',
        'psk_viterbi.v','psk_varicode.v','mode_config.vh','mfsk_varicode.vh','varicode.vh']]
    assert all(p.stat().st_mtime <= (out/variant/'simulation.log').stat().st_mtime for p in core_sources),'Rerun waveform tests after core changes'
    completed=re.findall(r'MODE (\d+) complete, max busy (\d+), demod (\d+), FEC (\d+) clocks',log)
    assert [int(row[0]) for row in completed]==list(range(len(MODES))),'Incomplete mode run'
    assert all(int(row[2])<3125 and int(row[3])<=10000 for row in completed),'Processing deadline failed'
log=(out/'board-simulation.log').read_text()
assert 'PASS ADC gain/framing/rate' in log and 'FAIL' not in log
rotary_log=(out/'rotary-simulation.log').read_text()
assert 'PASS rotary bounce' in rotary_log and 'FAIL' not in rotary_log
assert (ROOT/'rtl/psk/rotary_mode.v').stat().st_mtime <= (out/'rotary-simulation.log').stat().st_mtime,'Rerun rotary test after changes'
for label in ('fec-error-22','fec-error-24','fec-error-26','fec-midstream-22'):
    test=ROOT/f'build/{label}'
    if label.startswith('fec-error'):
        manifest=json.loads((test/'manifest.json').read_text())
        assert manifest['flipped_lsb_at_symbols']==[1000,1401,1802,2203,2604]
        assert hashlib.sha256((test/'symbols.hex').read_bytes()).hexdigest()==manifest['symbols_sha256']
    error_log=(test/'simulation.log').read_text()
    assert 'PASS FEC symbol run' in error_log and not re.search(r'FAIL|ERROR:|FATAL',error_log)
    from reference import PAYLOAD
    decoded=(test/'decoded.txt').read_text()
    start=decoded.find(PAYLOAD)
    assert start>=0,'Error-injection test did not decode text'
    decoded=decoded[start:]
    assert len(decoded)>=2*len(PAYLOAD)
    assert decoded==(PAYLOAD*(len(decoded)//len(PAYLOAD)+1))[:len(decoded)]
    assert all((ROOT/'rtl/psk'/p).stat().st_mtime <= (test/'simulation.log').stat().st_mtime
        for p in ('psk_decode.v','psk_fec_beam.v','mfsk_bit_decoder.v')),'Rerun FEC error tests after changes'
timing=(out/'psk_rx_top.twr').read_text()
assert re.search(r'Timing errors:\s+0\s+Score:\s+0',timing)
bit=out/'psk_rx_top.bit'
assert bit.stat().st_size>100000
sources=sorted((ROOT/'rtl/psk').glob('*'))+[ROOT/'constraints/psk_rx_top.ucf']
assert all(p.stat().st_mtime<=bit.stat().st_mtime for p in sources),'Rebuild after RTL changes'
assert all(p.stat().st_mtime<=(out/'board-simulation.log').stat().st_mtime for p in sources),'Rerun board simulation after changes'
sources += [ROOT/'scripts/psk/receiver.xst',ROOT/'scripts/psk/receiver.prj',bit]
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
(out/'validated.sha256').write_text(''.join(f'{v}  {k}\n' for k,v in hashes.items()),newline='\n')
(out/'validation.json').write_text(json.dumps({'sources_and_bitstream_sha256':hashes,
    'modes':[name for name,_,_ in MODES],
    'tests':[f'{len(MODES)} HPM modes nominal',f'{len(MODES)} HPM modes with noise, DC, inversion, frequency/sample error',
        'ADC gain, 34 clocks, sign, A/B lanes, 16 kHz, startup discard',
        'LCD pins, bootstrap, refresh, rotary preview/confirm, text clear',
        'Rotary debounce, direction, 27-mode wrap, hold and same-mode confirm',
        'ADC processing below 3125 clocks; FEC pair below 10000 clocks',
        'K7/K13/K16 five isolated symbol-bit errors corrected with contiguous text',
        'K16 joins at symbol 1500 inside continuous payload and reacquires',
        '50 MHz implementation timing'],
    'fec_decoder':'K5/K7 complete hard-decision Viterbi; K13/K16 64-survivor M-algorithm with GF(2) state acquisition',
    'excluded_hpm_modes':['2x8PSK1200F'],
    'hardware_audio_verified':False},indent=2))
print('PASS validation; bitstream ready for volatile JTAG programming')
