from io import BytesIO

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.units import inch

app = FastAPI(title="TAS Newsletter API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class NewsletterRequest(BaseModel):
    title: str
    content: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/generate")
def generate_newsletter(data: NewsletterRequest):
    buffer = BytesIO()
    doc = BaseDocTemplate(buffer, pagesize=LETTER)
    
    # 2 columns layout
    # Margins: 1 inch (72 points)
    margin = 0.75 * inch
    column_gap = 0.25 * inch
    column_width = (doc.width - column_gap) / 2
    
    frame1 = Frame(doc.leftMargin, doc.bottomMargin, column_width, doc.height, id='col1', showBoundary=0)
    frame2 = Frame(doc.leftMargin + column_width + column_gap, doc.bottomMargin, column_width, doc.height, id='col2', showBoundary=0)
    
    template = PageTemplate(id='two_columns', frames=[frame1, frame2])
    doc.addPageTemplates([template])
    
    styles = getSampleStyleSheet()
    title_style = styles['Title']
    body_style = styles['Normal']
    
    story = []
    story.append(Paragraph(data.title, title_style))
    story.append(Spacer(1, 0.2 * inch))
    
    # Simple markdown-like line break handling
    for line in data.content.split("\n"):
        if line.strip():
            story.append(Paragraph(line, body_style))
            story.append(Spacer(1, 0.1 * inch))
        else:
            story.append(Spacer(1, 0.1 * inch))
        
    doc.build(story)
    
    pdf_bytes = buffer.getvalue()
    buffer.close()

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": 'inline; filename="newsletter.pdf"'
        },
    )
