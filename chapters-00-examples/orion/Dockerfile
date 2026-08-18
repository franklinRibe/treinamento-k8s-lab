FROM python:3.13.7-alpine3.22@sha256:9ba6d8cbebf0fb6546ae71f2a1c14f6ffd2fdab83af7fa5669734ef30ad48844

WORKDIR /opt/orion
COPY app.py ./app.py

USER 10001:10001
EXPOSE 8080

CMD ["python", "-B", "/opt/orion/app.py"]
