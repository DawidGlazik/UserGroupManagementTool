#!/bin/bash

help(){
    echo ""
    echo "OPIS:"
    echo -e "\tTen skrypt pozwala na zarządzanie użytkownikami w formie graficznej. Umożliwia takie operacje jak:"
    echo -e "\t- dodawanie użytkowników,"
    echo -e "\t- usuwanie użytkowników,"
    echo -e "\t- zmianę składowych użytkowników (nazwa, hasło, itd.),"
    echo -e "\t- dodawanie grup,"
    echo -e "\t- usuwanie grup,"
    echo -e "\t- dodawanie wielu użytkowników na podstawie szablonu"
    echo "SPOSÓB UŻYCIA:"
    echo -e "\t./lusrmgr.sh [-h] [-v]"
    echo "OPCJE:"
    echo -e "\t-h\t\tWyświetl ten tekst pomocy."
    echo -e "\t-v\t\tWywietl informacje o wersji i autorze."
    echo "PRZYKŁADY UŻYCIA:"
    echo -e "\t./lusrmgr.sh"
    echo -e "\t./lusrmgr.sh -h"
    echo -e "\t./lusrmgr.sh -v"
    echo ""
    exit
}

ver(){
    echo ""
    echo "AUTOR: Dawid Glazik";
    echo "NR INDEKSU: 193069";
    echo "GRUPA: 5";
    echo ""
    exit
}

while getopts "hv" OPT; do
    case $OPT in
        h)
            help;;
        v)
            ver;;
    esac
done

if [ $UID -ne 0 ]; then
  zenity --error --text="Musisz być zalogowany jako root"
  exit
fi

TEST=`which finger`
if [[ -z "$TEST" ]]; then
    apt-get upgrade
    apt-get update
    apt-get install finger
fi

printUsers(){
    MENU=(`getent passwd {1000..2000} | cut -d: -f1 | sed 's/^/false /'`)
    ODP=`zenity --list --checklist --column=Check --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami" --separator="\n"`
}

printGroups(){
    MENU=(`getent group | cut -d: -f1 | sed 's/^/false /'`)
    ODP=`zenity --list --checklist --column=Check --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami" --separator="\n"`
}

formForNewUser(){
    FORM=`zenity --forms --title="Dodaj użytkownika" --text="Nowy użytkownik"\
        --add-entry="Nazwa użytkownika" \
        --add-entry="Pełna nazwa użytkownika" \
        --add-entry="Katalog domowy" \
        --add-entry="Grupa" \
        --add-password="Hasło" \
        --add-password="Powtórz hasło" \
        --add-calendar="Data wygaśnięcia" \
        --separator=","`
    if [[ $? -ne 0 ]]; then
        starter
        return 2
    fi
    NAME=`echo $FORM | cut -d ',' -f1`
    FULL_NAME=`echo $FORM | cut -d ',' -f2`
    HOME_FOLDER=`echo $FORM | cut -d ',' -f3`
    GROUP=`echo $FORM | cut -d ',' -f4`
    PASSWORD=`echo $FORM | cut -d ',' -f5`
    CONFIRM_PASSWD=`echo $FORM | cut -d ',' -f6`
    EXPIRES=`echo $FORM | cut -d ',' -f7`
}

addUser(){
    while [[ True ]]; do
        formForNewUser
        if [[ $? -eq 2 ]]; then
            return
        fi
        if [[ -z $NAME ]]; then
            zenity --error --text="Musisz podać nazwę użytkownika"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --error --text="Hasła nie są zgodne"
        else
            break
        fi
    done
    CMD="useradd -m"
    if [[ "$FULL_NAME" ]]; then
            if [[ "$FULL_NAME" =~ ^[a-zA-Z]+.*$ ]]; then
        	    CMD="$CMD -c '$FULL_NAME'"
            else
                zenity --error --text="Pełna nazwa musi rozpoczynać się od litery."
                starter
                return
            fi
	fi
    if [[ "$HOME_FOLDER" ]]; then
            if [[ "$HOME_FOLDER" =~ ^([\/]{1}.+)+$ ]]; then
        	    CMD="$CMD -d $HOME_FOLDER"
            else
                zenity --error --text="Niepoprawny adres folderu."
                starter
                return
            fi
	fi
    if [[ "$GROUP" ]]; then
            LIST=(`getent group | cut -d: -f1`)
            if [[ "${LIST[@]}" =~ "$GROUP" ]]; then
                CMD="$CMD -g $GROUP"
            else
                zenity --error --text="Taka grupa nie istnieje"
                starter
                return
            fi
	fi
    if [[ "$EXPIRES" ]]; then
            EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
        	CMD="$CMD -e $EXPIRES"
	fi
    if [[ "$PASSWORD" && $PASSWORD -eq $CONFIRM_PASSWD ]]; then
        CMD="$CMD -p $PASSWORD"
    fi
    if [[ "$NAME" =~ ^[a-zA-Z]+.*$ ]]; then
        LIST=(`getent passwd {1000..2000} | cut -d: -f1`)
            if [[ "${LIST[@]}" =~ "$NAME" ]]; then
                zenity --error --text="Użytkownik o takiej nazwie już istnieje"
                starter
                return
            else
                CMD="$CMD $NAME"
            fi
    else
        zenity --error --text="Nazwa musi rozpoczynać się od litery."
        starter
        return
    fi
    eval "$CMD"
    zenity --info --text="Dodano użytkownika $NAME"
    starter
}

delUser(){
    printUsers
    if [[ $? -ne 0 ]]; then
        starter
        return
    fi
    if [[ -z "$ODP" ]]; then
        zenity --error --text="Nie wybrano żadnego użytkownika."
        starter
        return
    fi
    SUMA=""
    for OPTION in $ODP; do
        CMD="userdel -r $OPTION"
        SUMA="$SUMA $OPTION,"
        eval "$CMD"
    done
    SUMA=${SUMA%?}
    zenity --info --text="Pomyślnie usunięto: $SUMA"
    starter
}

manageUser(){
    if [[ -z $1 ]]; then
        MENU=(`getent passwd {1000..2000} | cut -d: -f1`)
        ODP1=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami"`
        if [[ $? -ne 0 ]]; then
            starter
            return
        fi
    else
        ODP1="$1"
    fi
    MENU=("Zmień nazwę" "Zmień hasło" "Zmień pełną nazwę" "Zmień katalog domowy" "Zmień datę wygaśnięcia" "Dodaj do grupy" "Zablokuj użytkownika" "Odblokuj użytkownika")
    ODP2=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj - $ODP1"`
    if [[ $? -ne 0 ]]; then
        manageUser
        return
    fi
    case $ODP2 in
	"Zmień nazwę")
		NAME=`zenity --entry --text "Wprowadz nową nazwę:"`
        if [[ -z "$NAME" ]]; then
            zenity --error --text="Nie wprowadzono nazwy"
            manageUser "$ODP1"
            return
        else
            if [[ "$NAME" =~ ^[a-zA-Z]+.*$ ]]; then
                LIST=(`getent passwd {1000..2000} | cut -d: -f1`)
                    if [[ "${LIST[@]}" =~ "$NAME" ]]; then
                        zenity --error --text="Użytkownik o takiej nazwie już istnieje"
                        manageUser "$ODP1"
                        return
                    else
                        CMD="usermod -l '$NAME' $ODP1"
                        eval "$CMD"
                        zenity --info --text="Zmieniono nazwę użytkownika $ODP1 na $NAME"
                        manageUser "$NAME"
                        return
                    fi
            else
                zenity --error --text="Nazwa musi rozpoczynać się od litery."
                manageUser "$ODP1"
                return
            fi
        fi
        ;;
    "Zmień hasło")
        PASSWORD=`zenity --entry --text "Wprowadz nowe hasło:"`
        CONFIRM_PASSWD=`zenity --entry --text "Powtórz nowe hasło:"`
        if [[ -z "$PASSWORD" ]]; then
            zenity --error --text="Nie wprowadzono hasła"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --error --text="Hasła nie są takie same"
        else
            CMD='echo "$ODP1:$PASSWORD" | chpasswd > /dev/null 2>&1'
            eval "$CMD"
            zenity --info --text="Zmieniono hasło użytkownika $ODP1"
        fi
        manageUser "$ODP1"
		;;
    "Zmień pełną nazwę")
        FULL_NAME=`zenity --entry --text "Podaj nową pełną nazwę:"`
        if [[ -z "$FULL_NAME" ]]; then
            zenity --error --text="Nie wprowadzono pełnej nazwy"
            manageUser "$ODP1"
        else
            if [[ "$FULL_NAME" =~ ^[a-zA-Z]+.*$ ]]; then
        	    CMD="usermod -c '$FULL_NAME' $ODP1"
                eval "$CMD"
                zenity --info --text="Zmieniono pełną nazwę użytkownika $ODP1 na $FULL_NAME"
                manageUser "$ODP1"
                return
            else
                zenity --error --text="Pełna nazwa musi rozpoczynać się od litery."
                manageUser "$ODP1"
                return
            fi
        fi
		;;
	"Zmień katalog domowy")
        HOME_FOLDER=`zenity --entry --text "Podaj nowy katalog domowy:"`
        if [[ -z "$HOME_FOLDER" ]]; then
            zenity --error --text="Nie wprowadzono ścieżki dostępu"
            manageUser "$ODP1"
            return
        else
            if [[ "$HOME_FOLDER" =~ ^([\/]{1}.+)+$ ]]; then
        	    CMD="usermod -d $HOME_FOLDER $ODP1"
                eval "$CMD"
                zenity --info --text="Zmieniono katalog domowy użytkownika $ODP1 na $HOME_FOLDER"
                manageUser "$ODP1"
                return
            else
                zenity --error --text="Niepoprawny adres folderu."
                manageUser "$ODP1"
                return
            fi
        fi
		;;
	"Zmień datę wygaśnięcia")
        EXPIRES=`zenity --calendar --title="Wybór daty" --text="Kliknij na datę, aby ją wybrać"`
		if [[ -z "$EXPIRES" ]]; then
            zenity --error --text="Nie wybrano daty"
        else
            EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
        	CMD="usermod -e $EXPIRES $ODP1"
            eval "$CMD"
            zenity --info --text="Zmieniono datę wygaśnięcia konta użytkownika $ODP1 na $EXPIRES"
	    fi
        manageUser "$ODP1"
        ;;
	"Dodaj do grupy")
        printGroups
        CMD="usermod -G"
        SUMA=""
        if [[ -z "$ODP" ]]; then
            zenity --error --text="Nie wybrano ani jednej grupy"
        else
            for OPTION in $ODP; do
                CMD="$CMD$OPTION,"
                SUMA="$SUMA, $OPTION"
            done
            CMD=${CMD%?}
            CMD="$CMD $ODP1"
            eval "$CMD"
        fi
        SUMA=${SUMA%?}
        zenity --info --text="Dodano użytkownika $ODP1 do grup(y): $SUMA"
        manageUser "$ODP1"
		;;
	"Zablokuj użytkownika") 
        CMD="usermod -L $ODP1"
        eval "$CMD"
        zenity --info --text="Zablokowano użytkownika $ODP1"
        manageUser "$ODP1"
        ;;
    "Odblokuj użytkownika")
        CMD="usermod -U $ODP1"
        eval "$CMD"
        zenity --info --text="Odblokowano użytkownika $ODP1"
        manageUser "$ODP1"
        ;;
    esac
}

formForNewGroup(){
    FORM=`zenity --forms --title="Dodaj grupę" --text="Nowa grupa"\
        --add-entry="Nazwa grupy" \
        --add-entry="Katalog domowy" \
        --add-password="Hasło" \
        --add-password="Powtórz hasło" \
        --separator=","`
    if [[ $? -ne 0 ]]; then
        starter
        return 2
    fi
    NAME=`echo $FORM | cut -d ',' -f1`
    HOME_FOLDER=`echo $FORM | cut -d ',' -f2`
    PASSWORD=`echo $FORM | cut -d ',' -f3`
    CONFIRM_PASSWD=`echo $FORM | cut -d ',' -f4`
}

addGroup(){
    while [[ True ]]; do
        formForNewGroup
        if [[ $? -eq 2 ]]; then
            return
        fi
        if [[ -z $NAME ]]; then
            zenity --error --text="Musisz podać nazwę grupy"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --error --text="Hasła nie są zgodne"
        else
            break
        fi
    done
    CMD="groupadd"
    if [[ "$PASSWORD" && $PASSWORD -eq $CONFIRM_PASSWD ]]; then
        CMD="$CMD -p $PASSWORD"
    fi
    if [[ "$HOME_FOLDER" ]]; then
        if [[ "$HOME_FOLDER" =~ ^([\/]{1}.+)+$ ]]; then
    	    CMD="$CMD -R $HOME_FOLDER"
        else
            zenity --error --text="Niepoprawny adres folderu."
            starter
            return
        fi
	fi
    if [[ "$NAME" =~ ^[a-zA-Z]+.*$ ]]; then
        LIST=(`getent group | cut -d: -f1`)
        if [[ "${LIST[@]}" =~ "$NAME" ]]; then
            zenity --error --text="Grupa o takiej nazwie już istnieje"
            starter
            return
        else
            CMD="$CMD $NAME"
        fi
    else
        zenity --error --text="Nazwa musi rozpoczynać się od litery."
        starter
        return
    fi
    eval "$CMD"
    zenity --info --text="Dodano grupę $NAME"
    starter
}

delGroup(){
    printGroups
    if [[ $? -ne 0 ]]; then
        starter
        return
    fi
    if [[ -z "$ODP" ]]; then
        zenity --error --text="Nie wybrano żadnej grupy."
        starter
        return
    fi
    SUMA=""
    for OPTION in $ODP; do
        CMD="groupdel $OPTION"
        SUMA="$SUMA, $OPTION"
        eval "$CMD"
    done
    SUMA=${SUMA%?}
    zenity --info --text="Pomyślnie usunięto: $SUMA"
    starter
}

manageGroup(){
    if [[ -z $1 ]]; then
        MENU=(`getent group | cut -d: -f1`)
        ODP1=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Grupą"`
        if [[ $? -ne 0 ]]; then
            starter
            return
        fi
    else
        ODP1="$1"
    fi
    MENU=("Zmień nazwę" "Zmień hasło" "Zmień katalog domowy")
    ODP2=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj - $ODP1"`
    if [[ $? -ne 0 ]]; then
        manageGroup
        return
    fi
    case $ODP2 in
	"Zmień nazwę")
        NAME=`zenity --entry --text "Wprowadz nową nazwę:"`
        if [[ -z "$NAME" ]]; then
            zenity --error --text="Nie wprowadzono nazwy"
            manageGroup "$ODP1"
            return
        else
            if [[ "$NAME" =~ ^[a-zA-Z]+.*$ ]]; then
                LIST=(`getent group | cut -d: -f1`)
                if [[ "${LIST[@]}" =~ "$NAME" ]]; then
                    zenity --error --text="Grupa o takiej nazwie już istnieje"
                    manageGroup "$ODP1"
                    return
                else
                    CMD="groupmod -n '$NAME' $ODP1"
                    eval "$CMD"
                    zenity --info --text="Zmieniono nazwę grupy $ODP1 na $NAME"
                    manageGroup "$NAME"
                    return
                fi
            else
                zenity --error --text="Nazwa musi rozpoczynać się od litery."
                manageGroup "$ODP1"
                return
            fi
        fi
        ;;
    "Zmień hasło")
        PASSWORD=`zenity --entry --text "Wprowadz nowe hasło:"`
        CONFIRM_PASSWD=`zenity --entry --text "Powtórz nowe hasło:"`
        if [[ -z "$PASSWORD" ]]; then
            zenity --error --text="Nie wprowadzono hasła"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --error --text="Hasła nie są takie same"
        else
            CMD="groupmod -p $PASSWORD $ODP1"
            eval "$CMD"
        fi
        zenity --info --text="Zmieniono hasło grupy $ODP1"
        manageGroup "$ODP1"
        ;;
    "Zmień katalog domowy")
        HOME_FOLDER=`zenity --entry --text "Podaj nowy katalog domowy:"`
        if [[ -z "$HOME_FOLDER" ]]; then
            zenity --error --text="Nie wprowadzono ścieżki dostępu"
            manageGroup "$ODP1"
            return
        else
            if [[ "$HOME_FOLDER" =~ ^([\/]{1}.+)+$ ]]; then
        	    CMD="groupmod -R $HOME_FOLDER $ODP1"
                eval "$CMD"
                zenity --info --text="Zmieniono katalog domowy grupy $ODP1 na $HOME_FOLDER"
                manageGroup "$ODP1"
                return
            else
                zenity --error --text="Niepoprawny adres folderu."
                manageGroup "$ODP1"
                return
            fi
        fi
        ;;
    esac
}

formForManyUsers(){
    FORM=`zenity --forms --title="Dodaj użytkowników" --text="Nowi użytkownicy"\
        --add-entry="Nazwa użytkownika" \
        --add-entry="Liczba użytkowników" \
        --add-entry="Katalog domowy" \
        --add-entry="Grupa" \
        --add-calendar="Data wygaśnięcia" \
        --separator=","`
    if [[ $? -ne 0 ]]; then
        starter
        return 2
    fi
    NAME=`echo $FORM | cut -d ',' -f1`
    NUMBER=`echo $FORM | cut -d ',' -f2`
    HOME_FOLDER=`echo $FORM | cut -d ',' -f3`
    GROUP=`echo $FORM | cut -d ',' -f4`
    EXPIRES=`echo $FORM | cut -d ',' -f5`
}

addMany(){
    while [[ True ]]; do
        formForManyUsers
        if [[ $? -eq 2 ]]; then
            return
        fi
        if [[ -z $NAME ]]; then
            zenity --error --text="Musisz podać nazwę użytkowników"
        elif [[ -z $NUMBER ]]; then
            zenity --error --text="Musisz podać liczbę użytkowników"
        else
            break
        fi
    done
    TMP="_PASSWORDS"
    FILE="$NAME$TMP"
    for ((I=1; I<=$NUMBER; I++))
    do
        PASSWD=`openssl rand -base64 9 | head -c12`
        CMD="useradd -m"
        if [[ "$HOME_FOLDER" ]]; then
            if [[ "$HOME_FOLDER" =~ ^([\/]{1}.+)+$ ]]; then
        	    CMD="$CMD -d $HOME_FOLDER$I"
            else
                zenity --error --text="Niepoprawny adres folderu."
                starter
                return
            fi
        fi
        if [[ "$GROUP" ]]; then
            LIST=(`getent group | cut -d: -f1`)
            if [[ "${LIST[@]}" =~ "$GROUP" ]]; then
                CMD="$CMD -g $GROUP"
            else
                zenity --error --text="Taka grupa nie istnieje"
                starter
                return
            fi
	    fi
        if [[ "$EXPIRES" ]]; then
                EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
                CMD="$CMD -e $EXPIRES"
        fi
        CMD="$CMD -p $PASSWD"
        if [[ "$NAME" =~ ^[a-zA-Z]+.*$ ]]; then
            LIST=(`getent passwd {1000..2000} | cut -d: -f1`)
                if [[ "${LIST[@]}" =~ "$NAME" ]]; then
                    zenity --error --text="Użytkownik o takiej nazwie już istnieje"
                    starter
                    return
                else
                    CMD="$CMD $NAME"
                fi
        else
            zenity --error --text="Nazwa musi rozpoczynać się od litery."
            starter
            return
        fi
        eval "$CMD"
        echo "$NAME$I $PASSWD" >> $FILE
    done
    zenity --info --text="Dodano $NUMBER użytkowników o nazwie podstawowej $NAME"
    starter
}

info(){
    printUsers
    if [[ $? -ne 0 ]]; then
        starter
        return
    fi
    if [[ -z "$ODP" ]]; then
        zenity --error --text="Nie wybrano żadnego użytkownika."
    else
        for OPTION in $ODP; do
        CMD="finger $OPTION | tr '\t' '\n'; id $OPTION | tr ' ' '\n'; chage -l $OPTION"
        eval "$CMD" | zenity --text-info --height=400 --width=600 --title "Wynik - $OPTION"
        done
    fi
    starter
}

starter(){
    MENU=("Dodaj użytkownika" "Usuń użytkownika" "Zarządzaj użytkownikiem" "Dodaj grupę" "Usuń grupę" "Zarządzaj grupą" "Dodaj wiele użytkowników" "Info o użytkowniku")
    ODP=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami"`
    if [[ $? -ne 0 ]]; then
        return
    fi
    if [[ -z "$ODP" ]]; then
        zenity --error --text="Nie wybrano żadnej opcji."
        starter
        return
    fi
    case $ODP in
        "Dodaj użytkownika")
            addUser;;
        "Usuń użytkownika")
            delUser;;
        "Zarządzaj użytkownikiem")
            manageUser;;
        "Dodaj grupę")
            addGroup;;
        "Usuń grupę")
            delGroup;;
        "Zarządzaj grupą")
            manageGroup;;
        "Dodaj wiele użytkowników") 
            addMany;;
        "Info o użytkowniku")
            info;;
    esac
    if [[ $? -ne 0 ]]; then
        exit
    fi
}

zenity --text-info --html --title="Informacja" 2>/dev/null\
       --checkbox="Przeczytałem." --width=600 --height=400 --filename=/dev/stdin <<EOF
        <html><h3>Program do zarządzania użytkownikami i grupami</h3>
            <p>Wersja 1.0</p>
            <p>Autor: Dawid Glazik</p>
            <p>Opis programu:</p>
            <p>Program wykorzystuje bibliotekę zenity. Do poprawnego 
            działania wymagane jest zainstalowanie polecenia finger. 
            Inspiracją do stworzenia tego programu była przystawka 
            lusrmgr.msc z Windowsa. Program pozwala na wykonanie takich 
            operacji jak: dodanie użytkownika, usunięcie użytkownika, 
            zmianę parametrów użytkownika, dodanie grupy, usunięcie 
            grupy, modyfikację grupy, dodanie szeregu użytkowników na 
            podstawie podanych danych. Hasła do wygenerowanych kont 
            użytkowników pojawią się w pliku o nazwie 
            „bazowa_nazwa_użytkownika_PASSWORDS”.</p>
        </html>
EOF
case $? in
    0)
        starter
	;;
    -1)
        echo "Wystąpił nieoczekiwany błąd."
	;;
esac