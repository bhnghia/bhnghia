import {readdir,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const dir=new URL('../../supabase/migrations/',import.meta.url);
const files=(await readdir(dir)).filter(n=>n.endsWith('.sql')).sort();
if(!files.length)throw new Error('No migrations');
for(const name of files){const body=await readFile(new URL(name,dir));console.log(`${createHash('sha256').update(body).digest('hex')}  ${name}`);}
console.log(`Total: ${files.length}. Manifest only: no database connection or SQL execution.`);
