"""Collect verified ranges from separate ISim runs without losing raw logs."""
from reference import ROOT,PAYLOAD
from modes import MODES
import re,json,shutil
for variant in ('nominal','stress'):
    target=ROOT/f'build/psk/{variant}';target.mkdir(exist_ok=True)
    sources=[(ROOT/f'build/smoke-0-{variant}',range(22)),
             (ROOT/f'build/smoke-22-{variant}',range(22,27))]
    records=[];provenance=[]
    for group,(source,indices) in enumerate(sources):
        log=(source/'simulation.log').read_text()
        assert not re.search(r'FAIL|ERROR:|FATAL',log)
        parsed={int(m.group(1)):m.group(0) for m in re.finditer(
            r'MODE (\d+) complete, max busy (\d+), demod (\d+), FEC (\d+) clocks',log)}
        raw_name=f'raw-run-{group}.log'
        shutil.copy2(source/'simulation.log',target/raw_name)
        for index in indices:
            assert index in parsed,(source,index,'incomplete RTL simulation')
            name=MODES[index][0]
            text=(source/f'{name}.txt').read_text();start=text.find(PAYLOAD)
            assert start>=0,(name,variant,repr(text[:200]))
            text=text[start:]
            assert len(text)>=2*len(PAYLOAD),(name,'too little text')
            assert text==(PAYLOAD*(len(text)//len(PAYLOAD)+1))[:len(text)],(name,variant,repr(text[:300]))
            shutil.copy2(source/f'{name}.txt',target/f'{name}.txt')
            records.append(parsed[index])
            provenance.append(dict(mode=name,raw_log=raw_name,source_directory=str(source),
                                   contiguous_characters=len(text)))
    (target/'runs.json').write_text(json.dumps(provenance,indent=2))
    (target/'simulation.log').write_text(
        'Aggregated verification record; unmodified ISim logs are raw-run-0.log and raw-run-1.log.\n'
        'Modes 22-26 were rerun after correcting the stimulus ready handshake.\n'+
        '\n'.join(records)+'\nPASS RTL waveform run completed\n')
    print('PASS collected 27 verified modes:',variant)
