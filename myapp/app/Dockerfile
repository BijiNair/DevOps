FROM python:3.11-slim

WORKDIR /app

# Install runtime dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY . .

ENV FLASK_ENV=production
EXPOSE 8000

# Use gunicorn for production-like server
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "main:app"]