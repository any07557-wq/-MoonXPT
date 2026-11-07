"""Compile a separate module using only the public package, without publishing."""
from pathlib import Path
import argparse
import subprocess
import tempfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--library-dir',type=Path,help='consume an extracted library archive instead of this repository')
args=parser.parse_args()
project=(args.library_dir or Path(__file__).resolve().parents[1]).resolve()
with tempfile.TemporaryDirectory(prefix='moonxpt-consumer-') as name:
    root=Path(name)
    (root/'library').symlink_to(project,target_is_directory=True)
    c=root/'consumer';c.mkdir()
    (root/'moon.work').write_text('members = [ "library", "consumer" ]\n')
    (c/'moon.mod').write_text('name = "consumer/check"\npreferred_target = "native"\nimport { "any07557/moonxpt@0.1.0" }\n')
    (c/'moon.pkg').write_text('import { "any07557/moonxpt" @xpt }\npkgtype(kind: "executable")\n')
    (c/'main.mbt').write_text('''fn main {
      try {
        let bytes : Array[Byte] = []
        let writer=@xpt.Writer::new(@xpt.Output::new(b=>bytes.push_iter(b.iter())))
        writer.begin_dataset(@xpt.DatasetMetadata::new("PUBLIC",[@xpt.VariableMetadata::new("X",@xpt.Number,8,0)]))
        writer.write_row([@xpt.Numeric(@xpt.Missing(b'Z'))]);writer.finish()
        let reader=@xpt.Reader::new(@xpt.input_from_bytes(Bytes::from_array(bytes),chunk_size=1),options={ ..@xpt.ReadOptions::default(),row_hints:{"PUBLIC":1L} })
        ignore(reader.next_dataset())
        if reader.next_row().unwrap().values != [@xpt.Numeric(@xpt.Missing(b'Z'))] { abort("public value mismatch") }
        if reader.next_row()!=None || reader.next_dataset()!=None { abort("public EOF mismatch") }
        println("public API consumer PASS")
      } catch { _=>abort("public API consumer failed") }
    }
    ''')
    subprocess.run(['moon','run','consumer','--target','native'],cwd=root,check=True)
