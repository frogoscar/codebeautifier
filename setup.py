from setuptools import setup

setup(
    name='codebeautifier',
    version='0.99.0',
    description='Code formatting and style checking helper',
    author="Jean Guyomarc'h",
    author_email='jean.guyomarch-serv@ercom.fr',
    license='Private/Internal',
    classifiers=[
        # How mature is this project? Common values are
        #   3 - Alpha
        #   4 - Beta
        #   5 - Production/Stable
        'Development Status :: 4 - Beta',

        # Indicate who your project is intended for
        'Intended Audience :: Developers',
        'Topic :: Software Development :: Build Tools',

        # Specify the Python versions you support here. In particular, ensure
        # that you indicate whether you support Python 2, Python 3 or both.
        'Programming Language :: Python :: 3',
    ],
    keywords='linter code checker formatter',
    scripts=['codebeautifier'],
    install_requires=['argparse', 'colorlog'],
)
