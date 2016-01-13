FROM ubuntu:latest

EXPOSE 8000 9001

RUN apt-get -y update && apt-get install -y mysql-server curl python

COPY start.sh .

CMD ["./start.sh"]
