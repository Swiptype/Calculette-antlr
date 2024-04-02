export CLASSPATH=".:/usr/share/java/*:$CLASSPATH";

java org.antlr.v4.Tool code.g4;
javac code*.java;
antlr4-grun code 'calcul' -gui;

LANG=C.utf8 tp-compil-autocor code.g4 *.java