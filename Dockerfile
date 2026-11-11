FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --no-compile --requirement requirements.txt \
    && useradd --system --uid 10001 --create-home appuser

# Copy the rest of the project
COPY . .

USER 10001:10001

# Expose Flask default port
EXPOSE 5000

# Run the Flask application
CMD ["python", "app.py"]

