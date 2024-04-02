grammar code;

@parser::members {

    private TablesSymboles tablesSymboles = new TablesSymboles();

    private int _cur_label = 0;
    /** générateur de nom d'étiquettes pour les boucles */
    private String newLabel( ) { return "Label"+(_cur_label++); }; 

    private String evalOP (String op) {
        if ( op.equals("*") ){
            return "MUL ";
        } else if ( op.equals("/") ){
            return "DIV ";
        } else if ( op.equals("%") ){
            return "MOD ";
        } else if ( op.equals("+") ) {
            return "ADD ";
        } else if ( op.equals("-") ) {
            return "SUB ";
        } else if ( op.equals("==") ) {
            return "EQUAL ";
        } else if ( op.equals("<>") ) {
            return "NEQ ";
        } else if ( op.equals(">") ) {
            return "SUP ";
        } else if ( op.equals(">=") ) {
            return "SUPEQ ";
        } else if ( op.equals("<") ) {
            return "INF ";
        } else if ( op.equals("<=") ) {
            return "INFEQ ";
        }
        else {
            System.err.println("Opérateur arithmétique incorrect : '"+op+"'");
            throw new IllegalArgumentException("Opérateur arithmétique incorrect : '"+op+"'");
        }
    }
}

start : calcul EOF;

calcul returns [ String code ] 
@init{ $code = new String(); }   // On initialise une variable pour accumuler le code 
@after{ System.out.println($code); }
    :   (decl { $code += $decl.code; })*        
        { $code += "  JUMP Main\n"; }
        NEWLINE*
        
        (fonction { $code += $fonction.code; })* 
        NEWLINE*
        
        { $code += "LABEL Main\n"; }
        (instruction { $code += $instruction.code; })*

        { $code += "  HALT\n"; } 
    ;

instruction returns [ String code ] 
    : expression finInstruction 
        { 
            $code = $expression.code;
        }
    |  assignation finInstruction
        {
            $code = $assignation.code;
        }
    | 'readln(' IDENTIFIANT ')' finInstruction
        {
            VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
            if (vi.type.equals("int")){
                $code = "READ\n";
            }
            else if (vi.type.equals("double")){
                $code = "READF\n";
            }
            if (vi.scope == VariableInfo.Scope.GLOBAL) {
                $code += "STOREG " + vi.address + "\n";
            } else {
                $code += "STOREL " + vi.address + "\n";
            }
        }
    | 'println(' expression ')' finInstruction
        {
            $code = $expression.code;

            String type = $expression.type;

            if (type.equals("int")){
                $code += "WRITE\n";
            }
            else if (type.equals("double")){
                $code += "WRITEF\n";
            }
            
            $code += "POP\n";
        }
    | 'while' '('condition')' bloc_instruction
        {
            String d = newLabel() + "\n";
            String f = newLabel() + "\n";
            $code = "LABEL " + d +
                    $condition.code + 
                    "JUMPF " + f +
                    $bloc_instruction.code + 
                    "JUMP " + d + 
                    "LABEL " + f;
        }


    | 'if' '(' condition ')' a=bloc_instruction 
        {   String d = newLabel(); 
            String f = newLabel(); 
            String end = newLabel(); 
            
            $code = $condition.code; 
            $code += "JUMPF " + f + "\n";
            $code += $a.code; 
            $code += "JUMP " + end + "\n"; 
            $code += "LABEL " + f + "\n"; 
        }

     ('else' b=bloc_instruction  { $code += $b.code; })?
        {
            $code += "LABEL " + end + "\n"; 
        }

    | 'for' '(' declaration=assignation ';' condition ';' incrementation=assignation ')' bloc_instruction
        {
            String labelDebut = newLabel() + "\n";
            String labelFin = newLabel() + "\n";

            $code = $declaration.code;

            $code += "LABEL " + labelDebut +
                    $condition.code + 
                    "JUMPF " + labelFin +
                    $bloc_instruction.code + 
                    $incrementation.code + 
                    "JUMP " + labelDebut + 
                    "LABEL " + labelFin;
        }

    | RETURN expression finInstruction
        {
            $code = $expression.code;
            $code += "STOREL " + tablesSymboles.getReturn().address + "\n";
            $code += "RETURN\n";
        }

    | finInstruction
        {
            $code ="";
        }
    ;

expression returns [ String code, String type ]
    : a=expression op=('*' | '/' | '%') b=expression 
        {
            $code = $a.code + $b.code + evalOP($op.text) +"\n";

            if(VariableInfo.getSize($a.type) + VariableInfo.getSize($b.type) == 2){
                $type = "int";
            } else{
                $type = "double";
            }
        }
    | a=expression op=('+' | '-') b=expression 
        {
            $code = $a.code + $b.code + evalOP($op.text) +"\n";

            if(VariableInfo.getSize($a.type) + VariableInfo.getSize($b.type) == 2){
                $type = "int";
            } else{
                $type = "double";
            }
        }
    | '(' expression ')' 
        {
            $code = $expression.code;
            $type = $expression.type;
        }
    | '-' ENTIER
        {
            $code = "PUSHI -" + $ENTIER.text +"\n";
            $type = "int";
        }
    | ENTIER 
        {
            $code = "PUSHI " + $ENTIER.text +"\n";
            $type = "int";
        }
    | '-' FLOAT
        {
            $code = "PUSHF -" + $FLOAT.text +"\n";
            $type = "double";
        }
    | FLOAT
        {
            $code = "PUSHF " + $FLOAT.text +"\n";
            $type = "double";
        }
    | IDENTIFIANT
        {
            VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
            if (vi.scope == VariableInfo.Scope.GLOBAL) {
                $code = "PUSHG " + vi.address + "\n";
            } else {
                $code = "PUSHL " + vi.address + "\n";
            }

            $type = vi.type;
        }
    | IDENTIFIANT '('args')' 
        {
            $code = "PUSHI 0\n";
            $code += $args.code;
            $code += "CALL " + $IDENTIFIANT.text + "\n";
            for (int i = 0; i < $args.size; i++){
                $code += "POP \n";
            }

            $type = tablesSymboles.getFunction($IDENTIFIANT.text);
        }
    ;

finInstruction : ( NEWLINE | ';' )+ ;

decl returns [ String code ]
    :
        TYPE IDENTIFIANT finInstruction
        {
            $code = "PUSHI 0\n";
            tablesSymboles.addVarDecl($IDENTIFIANT.text,$TYPE.text);
        }
        | TYPE IDENTIFIANT '=' expression finInstruction
        {
            $code = "PUSHF 0.0\n";
            tablesSymboles.addVarDecl($IDENTIFIANT.text,$TYPE.text);
            VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
            $code += $expression.code;
            if (vi.scope == VariableInfo.Scope.GLOBAL){
                $code += "STOREG " + vi.address + "\n";
            } else {
                $code += "STOREL " + vi.address + "\n";
            }         
        }
    ;

assignation returns [ String code ]
    : IDENTIFIANT '=' expression
        {
            VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
            $code = $expression.code;
                if (vi.scope == VariableInfo.Scope.GLOBAL) {
                    $code += "STOREG " + vi.address + "\n";
                } else {
                    $code += "STOREL " + vi.address + "\n";
                }
        }
    | IDENTIFIANT '+=' expression
        {
            VariableInfo vi = tablesSymboles.getVar($IDENTIFIANT.text);
            if (vi.scope == VariableInfo.Scope.GLOBAL) {
                $code = "PUSHG " + vi.address + "\n";
            } else {
                $code = "PUSHL " + vi.address + "\n";
            }
            $code += $expression.code;
            $code += "ADD\n";
            if (vi.scope == VariableInfo.Scope.GLOBAL) {
                $code += "STOREG " + vi.address + "\n";
            } else {
                $code += "STOREL " + vi.address + "\n";
            }
        }
    ;


bloc returns [ String code ]  @init{ $code = new String(); } 
    : '{' 
            (instruction { $code += $instruction.code; })*
      '}'  
      NEWLINE*
    ;

bloc_instruction returns [ String code ]
    : bloc
    {
        $code = $bloc.code;
    }
    | instruction
    {
        $code = $instruction.code;
    }
    ;

condition returns [String code]
    : a=expression op=('=='|'<>'|'>'|'>='|'<'|'<=') b=expression
        {
            $code = $a.code + $b.code + evalOP($op.text) + "\n";
        } 

    | '!' condition
        {
            $code = $condition.code;
            $code += "PUSHI 1\n";
            $code += "NEQ\n";
        }

    | c=condition '&&' d=condition 
        {
            $code = $c.code + $d.code + "MUL\n";  
        }

    | c=condition '||' d=condition 
        {
            $code = $c.code + $d.code + "ADD\n";
            $code += "PUSHI 0\n";
            $code += "SUP\n";
        }

    | 'True' 
        { 
            $code = "  PUSHI 1\n";        
        }
    
    | 'False' 
        { 
            $code = "  PUSHI 0\n";
        }
    ;

params 
    : TYPE IDENTIFIANT
        {
            tablesSymboles.addParam($IDENTIFIANT.text, "int");          
        }
        ( ',' TYPE IDENTIFIANT
            {
                tablesSymboles.addParam($IDENTIFIANT.text, "int");
            }
        )*
    ;


fonction returns [ String code ]
@init {tablesSymboles.enterFunction();}
@after {tablesSymboles.exitFunction();}
    : 'fun' IDENTIFIANT '(' params ? ')' '->' TYPE
        {
            
            tablesSymboles.addFunction($IDENTIFIANT.text, $TYPE.text);

            String tmp = $IDENTIFIANT.text;
            $code = "LABEL " + tmp + "\n";
        }

        '{' 

        NEWLINE?

        (decl { $code += $decl.code; })*

        NEWLINE*

        (instruction { $code += $instruction.code; })*

        '}' 

        { 
            $code += "RETURN\n"; // Retour de sécurité
        }

        NEWLINE*
    ;

// init nécessaire à cause du ? final et donc args peut être vide (mais $args sera non null) 
args returns [ String code, int size] @init{ $code = new String(); $size = 0; }
    : ( expression
        {
            $code += $expression.code;
            $size += 1; 
        }
        ( ',' expression
            {
                $code += $expression.code;
                $size += 1; 
            }
        )*
      )?
    ;

// lexer

RETURN : 'return';

NEWLINE : '\r'? '\n' ;

WS : (' '|'\t')+ -> skip ;

ENTIER : ('0'..'9')+ ;

FLOAT : ('0'..'9')+ '.' ('0'..'9')*;

COMMENT_MONOLIGNE : '//' ~[\r\n]* -> skip;

COMMENT_MULTILIGNE : '/*' .*? '*/' -> skip;

TYPE : 'int' | 'double';

IDENTIFIANT
    :   ('a'..'z' | 'A'..'Z' | '_')('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*
    ;

UNMATCH : . -> skip ;