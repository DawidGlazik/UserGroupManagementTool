#!/bin/bash

help(){
    exit
}

ver(){
    echo "Autor: Dawid Glazik";
    echo "Nr indeksu: 193069";
    echo "Grupa: 5";
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
  echo "Musisz być zalogowany jako root"
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
        if [[ -z $NAME ]]; then
            zenity --info --text="Musisz podać nazwę użytkownika"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --info --text="Hasła nie są zgodne"
        else
            break
        fi
    done
    CMD="useradd -m"
    if [[ "$FULL_NAME" ]]; then
        	CMD="$CMD -c '$FULL_NAME'"
	fi
    if [[ "$HOME_FOLDER" ]]; then
        	CMD="$CMD -d $HOME_FOLDER"
	fi
    if [[ "$GROUP" ]]; then
        	CMD="$CMD -g $GROUP"
	fi
    if [[ "$EXPIRES" ]]; then
            EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
        	CMD="$CMD -e $EXPIRES"
	fi
    if [[ "$PASSWORD" && $PASSWORD -eq $CONFIRM_PASSWD ]]; then
        CMD="$CMD -p $PASSWORD"
    fi
    CMD="$CMD $NAME"
    eval "$CMD"
}

delUser(){
    printUsers
    for OPTION in $ODP; do
        CMD="userdel -r $OPTION"
        eval "$CMD"
    done
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
            zenity --info --text="Nie wprowadzono nazwy"
        else
            CMD="usermod -l '$NAME' $ODP1"
            eval "$CMD"
        fi
        manageUser "$ODP1"
        ;;
    "Zmień hasło")
        PASSWORD=`zenity --entry --text "Wprowadz nowe hasło:"`
        CONFIRM_PASSWD=`zenity --entry --text "Powtórz nowe hasło:"`
        if [[ -z "$PASSWORD" ]]; then
            zenity --info --text="Nie wprowadzono hasła"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --info --text="Hasła nie są takie same"
        else
            CMD='echo "$ODP1:$PASSWORD" | chpasswd > /dev/null 2>&1'
            eval "$CMD"
        fi
        manageUser "$ODP1"
		;;
    "Zmień pełną nazwę")
        FULL_NAME=`zenity --entry --text "Podaj nową pełną nazwę:"`
        if [[ -z "$FULL_NAME" ]]; then
            zenity --info --text="Nie wprowadzono pełnej nazwy"
        else
            CMD="usermod -c '$FULL_NAME' $ODP1"
            eval "$CMD"
        fi
        manageUser "$ODP1"
		;;
	"Zmień katalog domowy")
        HOME_FOLDER=`zenity --entry --text "Podaj nowy katalog domowy:"`
        if [[ -z "$HOME_FOLDER" ]]; then
            zenity --info --text="Nie wprowadzono ścieżki dostępu"
        else
            CMD="usermod -d $HOME_FOLDER $ODP1"
            eval "$CMD"
        fi
        manageUser "$ODP1"
		;;
	"Zmień datę wygaśnięcia")
        EXPIRES=`zenity --calendar --title="Wybór daty" --text="Kliknij na datę, aby ją wybrać"`
		if [[ -z "$EXPIRES" ]]; then
            zenity --info --text="Nie wybrano daty"
        else
            EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
        	CMD="usermod -e $EXPIRES $ODP1"
            eval "$CMD"
	    fi
        manageUser "$ODP1"
        ;;
	"Dodaj do grupy")
        printGroups
        CMD="usermod -G"
        if [[ -z "$ODP" ]]; then
            zenity --info --text="Nie wybrano ani jednej grupy"
        else
            for OPTION in $ODP; do
                CMD="$CMD$OPTION,"
            done
            CMD=${CMD%?}
            CMD="$CMD $ODP1"
            eval "$CMD"
        fi
        manageUser "$ODP1"
		;;
	"Zablokuj użytkownika") 
        CMD="usermod -L $ODP1"
        eval "$CMD"
        manageUser "$ODP1"
        ;;
    "Odblokuj użytkownika")
        CMD="usermod -U $ODP1"
        eval "$CMD"
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

    NAME=`echo $FORM | cut -d ',' -f1`
    HOME_FOLDER=`echo $FORM | cut -d ',' -f2`
    PASSWORD=`echo $FORM | cut -d ',' -f3`
    CONFIRM_PASSWD=`echo $FORM | cut -d ',' -f4`
}

addGroup(){
    while [[ True ]]; do
        formForNewGroup
        if [[ -z $NAME ]]; then
            zenity --info --text="Musisz podać nazwę grupy"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --info --text="Hasła nie są zgodne"
        else
            break
        fi
    done
    CMD="groupadd"
    if [[ "$PASSWORD" && $PASSWORD -eq $CONFIRM_PASSWD ]]; then
        CMD="$CMD -p $PASSWORD"
    fi
    if [[ "$HOME_FOLDER" ]]; then
        	CMD="$CMD -R $HOME_FOLDER"
	fi
    CMD="$CMD $NAME"
    eval "$CMD"
}

delGroup(){
    printGroups
    for OPTION in $ODP; do
        CMD="groupdel $OPTION"
        eval "$CMD"
    done
    starter
}

manageGroup(){
    MENU=(`getent group | cut -d: -f1`)
    ODP1=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami"`
    MENU=("Zmień nazwę" "Zmień hasło" "Zmień katalog domowy")
    ODP2=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj - $ODP1"`
    case $ODP2 in
	"Zmień nazwę")
        NAME=`zenity --entry --text "Wprowadz nową nazwę:"`
        if [[ -z "$NAME" ]]; then
            zenity --info --text="Nie wprowadzono nazwy"
        else
            CMD="groupmod -n '$NAME' $ODP1"
            eval "$CMD"
        fi
        ;;
    "Zmień hasło")
        PASSWORD=`zenity --entry --text "Wprowadz nowe hasło:"`
        CONFIRM_PASSWD=`zenity --entry --text "Powtórz nowe hasło:"`
        if [[ -z "$PASSWORD" ]]; then
            zenity --info --text="Nie wprowadzono hasła"
        elif [[ "$PASSWORD" != "$CONFIRM_PASSWD" ]]; then
            zenity --info --text="Hasła nie są takie same"
        else
            CMD="groupmod -p $PASSWORD $ODP1"
            eval "$CMD"
        fi
        ;;
    "Zmień katalog domowy")
        HOME_FOLDER=`zenity --entry --text "Podaj nowy katalog domowy:"`
        if [[ -z "$HOME_FOLDER" ]]; then
            zenity --info --text="Nie wprowadzono ścieżki dostępu"
        else
            CMD="groupmod -R $HOME_FOLDER $ODP1"
            eval "$CMD"
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

    NAME=`echo $FORM | cut -d ',' -f1`
    NUMBER=`echo $FORM | cut -d ',' -f2`
    HOME_FOLDER=`echo $FORM | cut -d ',' -f3`
    GROUP=`echo $FORM | cut -d ',' -f4`
    EXPIRES=`echo $FORM | cut -d ',' -f5`
}

addMany(){
    while [[ True ]]; do
        formForManyUsers
        if [[ -z $NAME ]]; then
            zenity --info --text="Musisz podać nazwę użytkowników"
        elif [[ -z $NUMBER ]]; then
            zenity --info --text="Musisz podać liczbę użytkowników"
        else
            break
        fi
    done
    TMP="_PASWORDS"
    FILE="$NAME$TMP"
    for ((I=1; I<=$NUMBER; I++))
    do
        PASSWD=`openssl rand -base64 9 | head -c12`
        CMD="useradd -m"
        if [[ "$HOME_FOLDER" ]]; then
        	CMD="$CMD -d $HOME_FOLDER$I"
        fi
        if [[ "$GROUP" ]]; then
                CMD="$CMD -g $GROUP"
        fi
        if [[ "$EXPIRES" ]]; then
                EXPIRES=`date -d "$(echo "$EXPIRES" | sed 's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3-\2-\1/')" +%Y-%m-%d`
                CMD="$CMD -e $EXPIRES"
        fi
        CMD="$CMD -p $PASSWD"
        CMD="$CMD $NAME$I"
        #eval "$CMD"
        #echo "$NAME$I $PASSWD" >> $FILE
    done
}

info(){
    printUsers
    for OPTION in $ODP; do
        CMD="finger $OPTION | tr '\t' '\n'; id $OPTION | tr ' ' '\n'; chage -l $OPTION"
        eval "$CMD" | zenity --text-info --height=400 --width=600 --title "Wynik - $OPTION"
    done
    starter
}

starter(){
    MENU=("Dodaj użytkownika" "Usuń użytkownika" "Zarządzaj użytkownikiem" "Dodaj grupę" "Usuń grupę" "Zarządzaj grupą" "Dodaj wiele użytkowników" "Info o użytkowniku")
    ODP=`zenity --list --column=Menu "${MENU[@]}" --height=400 --width=300 --title="Zarzadzaj Uzytkownikami"`
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

# zenity --text-info --html --title="Informacja" --text="eaksodginfbgid" \
#        --checkbox="Przeczytałem." --width=600 --height=400 --filename=/dev/stdin <<EOF
#         <html><big><b>Program do zarządzania użytkownikami i grupami</b></big>
#             <p>Wersja 1.0</p>
#             <p>Autor: Dawid Glazik</p>
#             <p>Opis programu:</p>
#             <p>Tu wpisz opis swojego programu.</p>
#         </html>
# EOF
# case $? in
#     0)
#         starter
# 	;;
#     -1)
#         echo "Wystąpił nieoczekiwany błąd."
# 	;;
# esac
starter