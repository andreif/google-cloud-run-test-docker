FROM python:3.12-alpine
EXPOSE 8080
ENTRYPOINT ["python", "-m", "http.server", "-d", "/tmp", "8080"]
