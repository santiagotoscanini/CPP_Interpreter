# CPP Interpreter Image

This image contains the required tools to follow course's book.

## Build Image

>docker build -t language-image .

`/langProg` is the working folder inside the image.

You can use this image in two ways:
 - work in the image's terminal
 - work executing docker run commands from a host's terminal
   
 Next two sections explains this two ways of working.

## Execute commands inside a docker terminal

To enter docker terminal in linux/mac:

>docker run --rm --volume $(pwd):/langProg -it language-image

In windows using powershell:

>docker run --rm --volume "$(pwd):/langProg" -it language-image

The working directory inside the image `/langProg` is mounted to the host's machine path where `docker run` is executed.

In image's terminal you can try the arithmetic expressions example (course's book chapter 2).

>root@06bc1448c066:/langProg# cd arithmetic-expressions
>root@06bc1448c066:/langProg/arithmetic-expressions# bnfc -m calc.cf
>
>8 rules accepted
>
>Use Alex 3.0 to compile LexCalc.x.
>ParCalc.y Tested with Happy 1.15
>writing new file ./AbsCalc.hs
>writing new file ./LexCalc.x
>writing new file ./ParCalc.y
>writing new file ./TestCalc.hs
>writing new file ./DocCalc.txt
>writing new file ./SkelCalc.hs
>writing new file ./PrintCalc.hs
>writing new file ./ErrM.hs
>writing new file ./Makefile

Next command compiles the generated parser.

>root@06bc1448c066:/langProg/arithmetic-expressions# make

>happy -gca ParCalc.y
>alex -g LexCalc.x
>ghc --make TestCalc.hs -o TestCalc
>
>PrintCalc.hs:1:33: warning:
>    -XOverlappingInstances is deprecated: instead use per-instance pragmas OVERLAPPING/OVERLAPPABLE/OVERLAPS
>  |
>1 | {-# LANGUAGE FlexibleInstances, OverlappingInstances #-}
>  |                                 ^^^^^^^^^^^^^^^^^^^^
>[1 of 7] Compiling AbsCalc          ( AbsCalc.hs, AbsCalc.o )
>[2 of 7] Compiling ErrM             ( ErrM.hs, ErrM.o )
>[3 of 7] Compiling LexCalc          ( LexCalc.hs, LexCalc.o )
>[4 of 7] Compiling ParCalc          ( ParCalc.hs, ParCalc.o )
>[5 of 7] Compiling PrintCalc        ( PrintCalc.hs, PrintCalc.o )
>[6 of 7] Compiling SkelCalc         ( SkelCalc.hs, SkelCalc.o )
>[7 of 7] Compiling Main             ( TestCalc.hs, TestCalc.o )
>Linking TestCalc ...

Next command executes previous generated `TestCalc` parser with the `5 + 6 * 7` arithmetic expressions.

>root@06bc1448c066:/langProg/arithmetic-expressions# echo "4 + 2" | ./TestCalc
>
>Parse Successful!
>
>[Abstract Syntax]
>
>EAdd (EInt 4) (EInt 2)
>
>[Linearized tree]
>
>4 + 2

The arithmetic expression could also be the content of a text file.

>root@06bc1448c066:/langProg/arithmetic-expressions# ./TestCalc expression.txt
>
>Parse Successful!
>
>[Abstract Syntax]
>
>EAdd (EInt 5) (EMul (EInt 6) (EInt 7))
>
>[Linearized tree]
>
>5 + 6 * 7

## Execute commands from host's console

Runs a bunch of commands to generate a parser of arithmetic expressions (course's book chapter 2 example)

>docker run --rm --volume $(pwd):/langProg -it language-image bash -c  "cd arithmetic-expressions; bnfc -m calc.cf; make"

Executes previous generated parser with arithmetic expressions `5 + 6 * 7`

>docker run --rm --volume $(pwd):/langProg -it language-image bash -c  'cd arithmetic-expressions; echo "5 + 6 * 7" | ./TestCalc'

Executes previous generated parser with a `expression.txt` input file.

>docker run --rm --volume $(pwd):/langProg -it language-image bash -c  'cd arithmetic-expressions; ./TestCalc expression.txt'

## Task 1

To run task 1 first we need to compile the Haskell file that run tests.

run `ghc --make -o progs-test-lab1 progs-test-lab1.hs` inside `Task 1/tests/lab1-testsuite` 

Then run the compiled file with the path to our .cf file.
`./progs-test-lab1 ../../Tokenizer & Parser & Abstract Syntax Tree/CPP.cf`
