FROM ubuntu:16.04

RUN apt update && apt install -yyq python3-pip pylint pylint3
RUN pip3 install colorlog autopep8

COPY codebeautifier /usr/bin/codebeautifier
COPY docker_resources/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod a+x /usr/bin/codebeautifier && chmod a+x /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["--help"]
