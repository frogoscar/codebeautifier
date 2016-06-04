FROM ubuntu:16.04

RUN apt update && apt install -yyq python3-pip pylint pylint3 clang-format-3.8 checkstyle
RUN pip3 install colorlog autopep8

ADD https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py /usr/bin/cpplint

COPY codebeautifier /usr/bin/codebeautifier
COPY unittest.sh /usr/bin/unittest
COPY docker_resources/entrypoint.sh /usr/bin/entrypoint.sh
COPY tests /opt/tests
RUN chmod a+x /usr/bin/codebeautifier && \
    chmod a+x /usr/bin/entrypoint.sh && \
    chmod a+x /usr/bin/unittest && \
    chmod a+x /usr/bin/cpplint

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["--help"]

