Codebeautifier
==============

Codebeautfier is a helper developed to ease the use of linters, style checkers
and code formatters by offering a generic interface.
It can be used by developpers before forging a commit and by scripts which
automate code style checking within the integration process.


Installation
------------

Codebeautifier can be installed by the following command (potentially as root):

```
#  python3 setup.py install
```

Note that the tools used by Codebeautifier are not included.
Please refer to the next section for more info about how to install these
utilities.


Supported Tools & Languages
---------------------------

Definitions:

- *formatter*: tool that modifies a file with respect to a formatting guide (e.g. google style);
- *checker*: tool that reads a file and outputs divergences between the code and a given coding style;
- *linter*: tool that analyses a file and warns about suspicious constructions in the code.

The table below shows the tools used by Codebeautifier.

| Tool              | Language        | Type           | How to Install (Ubuntu)                 |
| ----------------- | --------------- | -------------- | --------------------------------------- |
| [cpplint][1]      | C++             | Checker        | [cpplint.py][8]                         |
| [astyle][2]       | C++/Java        | Formatter      | Ubuntu package (`astyle`)               |
| [clang-format][3] | C++             | Formatter      | Ubuntu package (`clang-format-xxx`)     |
| [pylint][4]       | Python2         | Checker/Linter | Ubuntu package (`pylint`)               |
| [pylint3][5]      | Python3         | Checker/Linter | Ubuntu package (`pylint3`)              |
| [autopep8][6]     | Python2/Python3 | Formatter      | Ubuntu package (`python-autopep8`)      |
| [checkstyle][7]   | Java            | Checker/Linter | See [HERE][9]. v6.2 minimum is required |


General Usage
-------------

Codebeautifier general usage is expressed as it follows:

```
$  codebeautifier [verbosity] {check,format} [option(s)] file(s)/directory(ies)
```

On success, codebeautifier returns 0. On failure, it returns a non-zero value.

Help is available for:

- the global program: `codebeautifier --help`;
- the check argument: `codebeautifier check --help`;
- the format argument: `codebeautifier format --help`.

The verbosity consists in three modes:

- default: logs the command executed, their outputs, if a file could not be processed, when processing a file failed;
- verbose (`--verbose` or `-v`): displays more logs about the execution of the program;
- quiet (`--quiet` or `-q`): display only critical errors : when processing a file failed (still quiet when a file could not be processed).

The *check* and *format* options have their own sets of options, which are mainly:

- the strictness of the program (`--strict` or `-S`) : aborts when an error occurs (file could not be processed or processing failed);
- ignores (`--ignored-paths` or `-e`) : skips the files specified (regex);
- paths to tools : allow to specify the paths of the programs to be used. Please refer to the internal help for details (`--help`, `-h`).


Use Cases
---------

Check and format sources. The default behaviour should be sufficient for most developers:

```
$  codebeautifier check path/to/sources
$  codebeautifier format file.cc
```

Use a tool which is not installed:

```
$  codebeautifier check --pylint3 /path/to/where/I/downloaded/pylint
```

Within a script that needs to return only the files that failed to be processed:

```
$  codebeautifier -q check file/which/is/ill/formatted
```


Java Checker Exception
----------------------

The Java formatter used is checkstyle. It is possible to specify directly the JAR file (extension is required), or the Java class:

```
$  codebeautifier check --checkstyle /path/to/checkstyle.jar file.java
$  codebeautifier check --checkstyle com.puppycrawl.tools.checkstyle.Main file.java
```

Authors
-------

- Jean Guyomarc'h <jean.guyomarch-serv@ercom.fr>
- Alexandre Acebedo <alexandre.acebedo@ercom.fr>


License
-------

Codebeautifier is Copyright (c) 2015 - 2016 Ercom



[1]: https://google.github.io/styleguide/cppguide.html#cpplint
[2]: http://astyle.sourceforge.net/
[3]: http://clang.llvm.org/docs/ClangFormat.html
[4]: http://www.pylint.org/
[5]: http://packages.ubuntu.com/search?keywords=pylint3
[6]: https://pypi.python.org/pypi/autopep8/
[7]: http://checkstyle.sourceforge.net/
[8]: https://raw.githubusercontent.com/google/styleguide/gh-pages/cpplint/cpplint.py
[9]: http://checkstyle.sourceforge.net/#Download

