export class UploadBodyError extends Error { status:number;constructor(status:number){super('Dữ liệu upload không hợp lệ hoặc quá lớn.');this.status=status;} }
export async function boundedFormData(request:Request,maxBytes:number):Promise<FormData>{
 const length=request.headers.get('content-length');
 if(length&&(!/^\d+$/.test(length)||Number(length)>maxBytes))throw new UploadBodyError(413);
 if(!request.body)throw new UploadBodyError(400);
 const reader=request.body.getReader();const chunks:Uint8Array[]=[];let size=0;
 try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>maxBytes){await reader.cancel();throw new UploadBodyError(413);}chunks.push(value);}}finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
 try{return await new Response(bytes,{headers:{'Content-Type':request.headers.get('content-type')??''}}).formData();}catch{throw new UploadBodyError(400);}
}
