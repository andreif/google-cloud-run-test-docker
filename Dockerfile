FROM python:3.12-alpine
EXPOSE 8080
WORKDIR /app
ADD . /app
ENTRYPOINT ["python", "main.py"]
