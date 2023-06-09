with Ada.Text_IO; use Ada.Text_IO;
WITH Ada.integer_text_io; USE Ada.integer_text_io;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with p_intermediate; use p_intermediate;
with p_source; use p_source;
WITH object; use object;
with Ada.Text_IO; use Ada.Text_IO;
with op_string; use op_string;

package body p_assembler is

PROCEDURE AfficherL(line : String) IS
        str : access String;
        startQuote: Integer := 1;
        stopQuote: Integer := 1;
        startPlus: Integer := 0;
        stopPlus: Integer := 1;
        quoteClose: Boolean := True;
        index: Integer;
        spaceCounter: Integer := 0;
        tempVarName: access String := new String'("");
        doubleTempVarName: access String;
        bad_usage: Exception;
        tmp : Integer;
    BEGIN
        Put("");
        str := new String(1..(line'Last-line'First)+1);
        FOR i in 1..str.All'Last LOOP
            put("");
            str.All(i) := line(line'First+i-1);
        END LOOP;
        index := str.All'First;
        
        WHILE index <= str.All'Last LOOP
            IF str.All(index) = '"' AND startQuote <= index AND stopQuote <= startQuote AND Not quoteClose THEN
            -- Le string se termine
                stopQuote := index;
                quoteClose := True;
            ELSIF str.All(index) = '"' AND stopQuote <= index AND startQuote <= stopQuote AND quoteClose THEN
            -- Le string commence
                startQuote := index;
                quoteClose := False;
                -- Réinitialisation de la variable temporaire
                Put("");
                tempVarName := new String'("");
                Put("");
                doubleTempVarName := new String'("");
            ELSIF index > startQuote AND stopQuote <= startQuote AND Not quoteClose THEN
            -- Le contenu du string
                Put("");
                tmp := str.All'Length;
                object.Put(str.All(index));

            ELSIF str.All(index) = ' ' and quoteClose THEN
                spaceCounter := spaceCounter + 1;
                NULL;

            ELSIF str.All(index) = '+' AND startPlus <= index AND stopPlus < startPlus AND quoteClose THEN
            -- Concatenation se termine
                stopPlus := index;
                -- Transformation de la variable en valeur ou prise de la valeur brute
                -- Affichage de la valeur
                Put("");
                tmp := tempVarName.All'Length;
                Put(TrimI(GetVarValue(Upper_Case(tempVarName.All))));
            ELSIF str.All(index) = '+' AND stopPlus <= index AND startPlus < stopPlus AND quoteClose THEN
            -- Concatenation commence
                startPlus := index;
            ELSIF index > startPlus AND stopPlus <= startPlus THEN
                -- Sauvegarde du caractère pour former le nom de la variable finale ou la valeur brute finale
                Put("");
                doubleTempVarName := new String'(tempVarName.All);
                Put("");
                tempVarName := new String'(doubleTempVarName.All&str.All(index));
                IF index = str.All'Last AND stopPlus <= startPlus THEN
                -- Si il n'y pas d'autres chaine à concaténer derriere
                    -- Affichage de la valeur
                    Put("");
                    tmp := tempVarName.All'Length;
                    Put(TrimI(GetVarValue(Upper_Case(tempVarName.All))));
                END IF;
            
            ELSIF index = spaceCounter+1 THEN
                startPlus := index-2;
                stopPlus := startPlus;
                index := index-1;

            ELSE
                RAISE bad_usage;

            END IF;

                
            index := index + 1;
        END LOOP;

    EXCEPTION
        WHEN bad_usage =>
            New_Line;
            Put_Line("Mauvais usage de la fonction AFFICHER");
    END AfficherL;



    PROCEDURE Traitement(inst: String ; line: P_LISTE_CH_CHAR.T_LISTE) IS
    BEGIN
        IF Index(inst, "L") = 1 THEN
        -- C'est soit un label, soit une affectation
            IF Index(inst, " ") = Index(inst, "<-")-1 THEN
            -- C'est une affectation pour une variable dont le nom commence par 'L'
                TraiterAffectation(inst);
            ELSE
            -- C'est une création de label
                -- Le label est déjà affecté à l'instruction, il faut maintenant executer l'instruction
                Traitement(inst(Index(inst, " ")+1..inst'Last), line);
            END IF;
        END IF;

        IF Index(Upper_Case(inst), "AFFICHER(") > 0 THEN
        -- C'est un affichage
            AfficherL(inst(Index(Upper_Case(inst), "AFFICHER(")+9..Index(inst, ")")-1));
        ELSIF Index(inst, ":") > 0 THEN
        -- Ce sont les déclarations
            TraiterDeclarations(inst);

        ELSIF Index(inst, "<-") > 0 THEN
        -- C'est une affectation
            TraiterAffectation(inst);

        ELSIF Index(inst, "RETOUR") > 0 THEN
        -- C'est un retour à la ligneENTETE
            New_Line;

        ELSE
            NULL;

        END IF;


    END Traitement;

    PROCEDURE TraiterInstructions(debug: Boolean) IS
        liste: P_LISTE_CH_CHAR.T_LISTE := GetFile.instructions;
    BEGIN
        IF debug THEN
            Put_Line("====== MODE DEBUG ACTIVE ======");
        END IF;

        -- Premier tour de boucle pour initialiser les labels
        WHILE P_LISTE_CH_CHAR.isNull(liste) LOOP
            IF Index(liste.All.Element.All, "L") = 1 THEN
            -- C'est soit un label, soit une affectation
                IF Index(liste.All.Element.All, " ") = Index(liste.All.Element.All, "<-")-1 THEN
                -- C'est une affectation pour une variable dont le nom commence par 'L'
                -- Aucun traitement pour l'instant
                    NULL;
                ELSE
                -- C'est une création de label
                    TraiterLabel(liste.All.Element.All(liste.All.Element.All'First..Index(liste.All.Element.All, " ")-1), liste);
                    
                    IF debug THEN
                    -- Affichage en mode debug
                        Put_Line("====== AJOUT D'UN LABEL | LISTE DES LABELS : ======");
                        WHILE P_LISTE_CLEFVALEUR.isNull(label_map.All.Suivant) LOOP
                            Put_Line(CV_ToString(label_map.All.Element));
                        END LOOP;
                    END IF;

                END IF;
            END IF;
            liste := liste.All.Suivant;
        END LOOP;

        -- Deuxième tour pour effectuer les traitements
        liste := GetFile.instructions;
        WHILE P_LISTE_CH_CHAR.isNull(liste) LOOP
            IF debug THEN
            -- Affichage en mode debug
                Put_Line("LIGNE "&Integer'Image(GetCP));
                Put_Line("INSTRUCTION : ");
                Put_Line(liste.All.Element.All);
                Put_Line("====== VARIABLES DECLAREES : ======");
                WHILE P_LISTE_VARIABLE.isNull(Declared_Variables.All.Suivant) LOOP
                    Put_Line(Image_Variable(Declared_Variables.All.Element));
                END LOOP;
            END IF;
            -- Check pour ce qui ne concerne pas le GOTO
            Traitement(liste.All.Element.All, liste);
            IF Index(liste.All.Element.All, "GOTO") > 0 THEN
                liste := TraiterGOTO(liste);
            ELSE
                liste := liste.All.Suivant;
            END IF; 
        END LOOP;
    
    END TraiterInstructions;



    PROCEDURE TraiterDeclarations(line : String) IS
        value1: access String;
        value2: access String;
        var: Variable;
    BEGIN
        IF Index(line, ", ") > 0 THEN
            Put("");
            value1 := new String'(line(line'First..Index(line, ", ")-1));
            Put("");
            value2 := new String'(line(Index(line, ", ")+2..line'Last));
            var := (
                new String'(value1.All),
                False,
                0,
                new String'("Entier")
            );
            P_LISTE_VARIABLE.ajouter(Declared_Variables, var);
            WHILE Index(value2.All, ", ") > 0 LOOP
                var := (
                    new String'(value2.All(value2.All'First..Index(value2.All, ", ")-1)),
                    False,
                    0,
                    new String'("Entier")
                );
                P_LISTE_VARIABLE.ajouter(Declared_Variables, var);
                Put("");
                value2 := new String'(value2.All(Index(value2.All, ", ")+2..line'Last));
            END LOOP;
            var := (
                new String'(value2.All(value2.All'First..Index(line, " : Entier")-1)),
                False,
                0,
                new String'("Entier")
            );
            P_LISTE_VARIABLE.ajouter(Declared_Variables, var);
        ELSE
            var := (
                new String'(line(line'First..Index(line, " : Entier")-1)),
                False,
                0,
                new String'("Entier")
            );
            P_LISTE_VARIABLE.ajouter(Declared_Variables, var);
        END IF;
    END TraiterDeclarations;

    PROCEDURE TraiterAffectation(line : String) IS
        var: P_LISTE_VARIABLE.T_LISTE := Declared_Variables;
        val: Integer;
    BEGIN
        var := IsVarExisting(line(line'First..Index(line, " <-")-1));

        IF Index(line, "+") > 0 OR Index(line, " -") > 0 OR
         Index(line, "*") > 0 OR Index(line, "/") > 0 THEN
            val := AppliquerOperation(line(Index(line, "<- ")+3..line'Last));
            var.All.Element.value := val;
        ELSIF Index(line, "=") > 0 OR Index(line, "!=") > 0 OR Index(line, ">") > 0 OR
         Index(line, "< ") > 0 OR Index(line, ">=") > 0 OR Index(line, "<=") > 0
         OR Index(line, "OR") > 0 OR Index(line, "AND") > 0 THEN
            IF AppliquerCondition(line(Index(line, "<- ")+3..line'Last)) THEN
                val := 1;
            ELSE
                val := 0;
            END IF;
            var.All.Element.value := val;
        ELSE
            var.All.Element.value := GetVarValue(line(Index(line, "<- ")+3..line'Last));
        END IF;
    END TraiterAffectation;

    --Pour me rappeler de raconter la dinguerie eca

    FUNCTION RechercherMap(liste : P_LISTE_CLEFVALEUR.T_LISTE ; label : String) RETURN P_LISTE_CLEFVALEUR.T_LISTE IS
        listeCourante : P_LISTE_CLEFVALEUR.T_LISTE := liste;
    BEGIN
        WHILE P_LISTE_CLEFVALEUR.isNull(listeCourante) AND THEN listeCourante.All.Element.Clef.All /= label LOOP
            listeCourante := listeCourante.All.Suivant;
        END LOOP;

        RETURN listeCourante;
    END RechercherMap;

    FUNCTION TraiterGOTO(listeCourante: P_LISTE_CH_CHAR.T_LISTE) RETURN P_LISTE_CH_CHAR.T_LISTE IS
        line: String := listeCourante.All.Element.All;
    BEGIN
        IF Index(line, "IF") > 0 THEN
            IF VerifierCondition(line(Index(line, "IF ")+3..Index(line, " GOTO")-1)) THEN
                RETURN rechercherMap(label_map, line(Index(line, "GOTO ")+5..line'Last)).All.Element.Valeur;
            ELSE
                RETURN listeCourante.all.Suivant;
            END IF;
        ELSE
            RETURN rechercherMap(label_map, line(Index(line, "GOTO ")+5..line'Last)).
            All.
            Element.
            Valeur;
        END IF;
    END TraiterGOTO;

    FUNCTION VerifierCondition(condition: String) RETURN Boolean IS
        var: P_LISTE_VARIABLE.T_LISTE := Declared_Variables;
    BEGIN
        var := IsVarExisting(condition);
        IF var.All.Element.value = 1 THEN
            RETURN True;
        ELSE
            RETURN False;
        END IF;
    END VerifierCondition;

    PROCEDURE TraiterLabel(label: String; line: P_LISTE_CH_CHAR.T_LISTE) IS
        Map_Entry: T_CLEFVALEUR;
    BEGIN
        Map_Entry := (new String'(label), line);
        P_LISTE_CLEFVALEUR.ajouter(label_map, Map_Entry);
    END TraiterLabel;



    FUNCTION AppliquerCondition(cond: String) RETURN Boolean IS
        value1: access String;
        value2: access String;
        valInt1: Integer;
        valInt2: Integer;
    BEGIN
        Put("");
        IF Index(cond, " < ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " <")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "< ")+2..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 < valInt2);
        ELSIF Index(cond, " > ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " >")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "> ")+2..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 > valInt2);
        ELSIF Index(cond, " <= ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " <=")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "<= ")+3..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 <= valInt2);
        ELSIF Index(cond, " >= ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " >=")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, ">= ")+3..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 >= valInt2);
        ELSIF Index(cond, " = ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " =")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "= ")+2..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 = valInt2);
        ELSIF Index(cond, " != ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " !=")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "!= ")+3..cond'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN (valInt1 /= valInt2);
        ELSIF Index(cond, " OR ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " OR")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "OR ")+3..cond'Last));
            valInt2 := GetVarValue(value2.All);
            IF valInt1 = 1 THEN
                IF valInt2 = 1 THEN
                    RETURN True;
                ELSE
                    RETURN True;
                END IF;
            ELSE
                IF valInt2 = 1 THEN
                    RETURN True;
                ELSE
                    RETURN False;
                END IF;
            END IF;
        ELSIF Index(cond, " AND ") > 0 THEN
            Put("");
            value1 := new String'(cond(cond'First..Index(cond, " AND")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(cond(Index(cond, "AND ")+4..cond'Last));
            valInt2 := GetVarValue(value2.All);
            IF valInt1 = 1 THEN
                IF valInt2 = 1 THEN
                    RETURN True;
                ELSE
                    RETURN False;
                END IF;
            ELSE
                IF valInt2 = 1 THEN
                    RETURN False;
                ELSE
                    RETURN False;
                END IF;
            END IF;
        ELSE
            -- TODO: RAISE ERROR ?
             RETURN True; -- Remplace un NULL
        END IF;
    END AppliquerCondition;

    FUNCTION AppliquerOperation(op: String) RETURN Integer IS
        value1: access String;
        value2: access String;
        valInt1: Integer;
        valInt2: Integer;
    BEGIN
        IF Index(op, "+") > 0 THEN
            value1 := new String'(op(op'First..Index(op, " +")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(op(Index(op, "+ ")+2..op'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN valInt1+valInt2;
        ELSIF Index(op, "-") > 0 THEN
            Put("");
            value1 := new String'(op(op'First..Index(op, " -")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(op(Index(op, "- ")+2..op'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN valInt1-valInt2;
        ELSIF Index(op, "*") > 0 THEN
            value1 := new String'(op(op'First..Index(op, " *")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(op(Index(op, "* ")+2..op'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN valInt1*valInt2;
        ELSIF Index(op, "/") > 0 THEN
            Put("");
            value1 := new String'(op(op'First..Index(op, " /")-1));
            valInt1 := GetVarValue(value1.All);
            Put("");
            value2 := new String'(op(Index(op, "/ ")+2..op'Last));
            valInt2 := GetVarValue(value2.All);
            RETURN valInt1/valInt2;
        ELSE
            -- TODO: Exception ?
            RETURN 0; -- Remplace un NULL
        END IF;
    END AppliquerOperation;


    FUNCTION GetVarValue(val: String) RETURN Integer IS
        liste: P_LISTE_VARIABLE.T_LISTE;
    BEGIN
        liste := IsVarExisting(val);
        IF liste.All.Element.intitule.All = val THEN
            RETURN liste.All.Element.value;
        ELSE
            RETURN Integer'Value(val);
        END IF;
    EXCEPTION
        WHEN others =>
            IF val = "FAUX" THEN
                RETURN 0;
            ELSIF val = "VRAI" THEN
                RETURN 1;
            ELSE
                Put_Line("La variable : "&val&" n'existe pas");
                RAISE;
            END IF;
    END GetVarValue;


    FUNCTION IsVarExisting(val: String) RETURN P_LISTE_VARIABLE.T_LISTE IS
        var_exist: P_LISTE_VARIABLE.T_LISTE;
    BEGIN
        var_exist := Declared_Variables;
        WHILE P_LISTE_VARIABLE.isNull(var_exist) AND THEN var_exist.All.Element.intitule.All /= val LOOP
            IF var_exist.All.Suivant /= NULL THEN
                var_exist := var_exist.All.Suivant;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        RETURN var_exist;
    END IsVarExisting;

end p_assembler;