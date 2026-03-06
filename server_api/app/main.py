from io import BytesIO

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel
from reportlab.lib.pagesizes import LETTER
from reportlab.pdfgen import canvas

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
    pdf = canvas.Canvas(buffer, pagesize=LETTER)

    width, height = LETTER
    margin_x = 72
    y = height - 72

    pdf.setFont("Helvetica-Bold", 20)
    pdf.drawString(margin_x, y, data.title)
    y -= 40

    pdf.setFont("Helvetica", 12)

    for line in data.content.split("\n"):
        if y < 72:
            pdf.showPage()
            pdf.setFont("Helvetica", 12)
            y = height - 72

        pdf.drawString(margin_x, y, line[:100])
        y -= 20

    pdf.save()

    pdf_bytes = buffer.getvalue()
    buffer.close()

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": 'inline; filename="newsletter.pdf"'
        },
    )
