"""Generate fictional raster-only/mixed PDF fixtures (Pillow required locally)."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import io
out=Path(__file__).resolve().parents[1]/'erlang/apps/bright_studio/test/fixtures'
out.mkdir(exist_ok=True)
image=Image.new('RGB',(1400,1800),'white');draw=ImageDraw.Draw(image)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',46)
for y,line in enumerate(['A scanned learning page','Bright Studio OCR preserves useful ideas.','Read carefully and keep the evidence.']):draw.text((90,180+y*95),line,fill='black',font=font)
b=io.BytesIO();image.save(b,'JPEG',quality=90);jpeg=b.getvalue()
def pdf(mixed=False):
 raster=b'q 600 0 0 780 0 0 cm /Image1 Do Q'
 objects=[b'<< /Type /Catalog /Pages 2 0 R >>', b'<< /Type /Pages /Kids '+(b'[3 0 R 7 0 R] /Count 2' if mixed else b'[3 0 R] /Count 1')+b' >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 780] /Resources << /XObject << /Image1 4 0 R >> >> /Contents 5 0 R >>',b'<< /Type /XObject /Subtype /Image /Width 1400 /Height 1800 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length '+str(len(jpeg)).encode()+b' >>\nstream\n'+jpeg+b'\nendstream',b'<< /Length '+str(len(raster)).encode()+b' >>\nstream\n'+raster+b'\nendstream',b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
 if mixed:
  digital=b'BT /F1 16 Tf 40 700 Td (Embedded text stays readable.) Tj ET'
  objects +=[b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 780] /Resources << /Font << /F1 6 0 R >> >> /Contents 8 0 R >>',b'<< /Length '+str(len(digital)).encode()+b' >>\nstream\n'+digital+b'\nendstream']
 data=b'%PDF-1.4\n';offsets=[]
 for i,o in enumerate(objects,1):offsets.append(len(data));data+=str(i).encode()+b' 0 obj\n'+o+b'\nendobj\n'
 xref=len(data);data+=f'xref\n0 {len(objects)+1}\n0000000000 65535 f \n'.encode()+b''.join(f'{o:010d} 00000 n \n'.encode() for o in offsets)+f'trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode();return data
(out/'scanned.pdf').write_bytes(pdf());(out/'mixed.pdf').write_bytes(pdf(True))
