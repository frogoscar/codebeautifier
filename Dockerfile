FROM ubuntu:16.04

RUN apt update && apt install -yyq pylint pylint3 clang-format-3.8 checkstyle python3-colorlog python-autopep8 python-pep8

ADD https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py /usr/bin/cpplint

COPY codebeautifier /usr/bin/codebeautifier
COPY unittest.sh /usr/bin/unittest
COPY docker_resources/entrypoint.sh /usr/bin/entrypoint.sh
COPY tests /opt/tests
RUN chmod a+rx /usr/bin/codebeautifier && \
    chmod a+rx /usr/bin/entrypoint.sh && \
    chmod a+rx /usr/bin/unittest && \
    chmod a+rx /usr/bin/cpplint

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["--help"]
