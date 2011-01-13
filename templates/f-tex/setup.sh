#!/bin/bash


# Setup script fuer die Nutzung der fancy-LaTeX Umgebung oder
# der Label-Print erweiterung (lp) in LX-Office-erp.
# Welches Setup ist von der Position innerhalb des Dateisystems abhaengig.
# Das Script kann auch nach erfolgtem Setup erneut aufgerufen werden

#   see  ./setup.sh -h





# Revision 0.2  (13.02.2011) add lp
#                            setup add determination of company data
# Revision 0.1  (19.12.2010) initial script create


# config

DB_AUTH='../../config/lx_office.conf'

FILE_LIST_FTEX='
   letter.tex
   sample.lco
   sample_head.pdf
   translations.tex
   xstring.sty
   zwischensumme.sty
'

FILE_LIST_LP='
   label_abs_a7_de.tex
   label_nn_brief_a4_de.tex
   zweckform_3427.tdf
   zweckform_3483.tdf
'


DOC_TYPE_FTEX='
   invoice
   proforma
   sales_quotation
   sales_order
   sales_delivery_order
   credit_note
   pick_list
   purchase_order
'


LXO_DETERMINE='
   ../../SL/Form.pm
   ../../config/lx_office.conf.default
   ../../doc/changelog
'

CHK_RAWNUMBER_PATCH='
   ../../SL/DO.pm
   ../../SL/IS.pm
   ../../SL/OE.pm
'

MY_DATA='
  employeecountry
  labelcompanyname
  labelbankname
  labelbankcode
  labelbankaccount
  MYfromname
  MYaddrsecrow
  MYrechtsform
  MYfromaddress
  MYfromphone
  MYfromfax
  MYfromemail
  MYsignature
  MYustid
  MYfrombank
'

BASE_DIR=`readlink -f $0 | sed 's/setup\.sh$//'`

MODUL=`basename ${BASE_DIR}`
export TEXINPUTS=".:${BASE_DIR}:"

OK='...... [ok]'
MARK='\033[1;34m'
UNMARK='\033[0m'
TIME=`date +%s`

USAGE="\n\n  setup LaTeX templates for lx-office erp (www.lx-office.org)
\n\n  USAGE: ./`basename $0` [OPTION] \n
\n
  -h print this Help\n
\n
\n
  OPTIONS for trouble shooting:\n\n
  -D don't connect to any database\n
  -C no colored output (don't use any terminal escape character)\n
\n\n
  RECOMMENDED USE ./setup.sh

\n
"

# script control

DATABASE=1

while getopts  "hDC" flag
do
  case $flag in
    h)
       echo -e ${USAGE}
       exit
       ;;
    D)
       DATABASE=0
       ;;
    C)
       NO_COLOR=1
       ;;
  esac
done

# Disclaim

cat << EOD

   ##########################################################################
   #                        Disclaimer                                      #
   ##########################################################################
   #                                                                        #
   # Dies ist ein Script zum Einrichten von LaTeX Templates                 #
   # (fancy-latex (f-tex)) oder (label-print (lp) fuer                      #
   #                                                                        #
   #      lx-office erp (www.lx-erp.org)                                    #
   #                                                                        #
   # Obwohl LX-Office sich an deutschsprachige Anwender richtet ist dieses  #
   # Script in Englisch und soll auch nicht uebersetzt werden.              #
   #                                                                        #
   # * es richtet sich an System-Administratoren                            #
   # * da es das Script nur in einer Sprache gibt, ist es viel leichter     #
   #   bei Fehlern und Fehlermeldungen aus dem Script selbst, im Internet   #
   #   nach Loesungen zu suchen.                                            #
   #                                                                        #
   ##########################################################################
   #                                                                        #
   # This script provides an easy to use setup for the fancy LaTeX          #
   # environment of lx-office erp (templates/f-tex)                         #
   #                                                                        #
   # Normal use is to run ./setup.sh without any parameter. You may also    #
   # check                                                                  #
   #   ./setup.sh -h                                                        #
   # for help.                                                              #
   #                                                                        #
   # The script tries to be as save as possible to avoid unwanted file      #
   # overwriting by being very interactive. It's designed to be invoked     #
   # multiple times inside the same template directory. So it is possible   #
   # to rerun the script if there are updates available or after you break  #
   # your LaTeX templates by any changes.                                   #
   #                                                                        #
   # I recommend to backup your installation and database before you run    #
   # this script.                                                           #
   #                                                                        #
   # ANYHOW: I do not take responsibility for any harm initiated by this    #
   #         script. (Wulf Coulmann -- scripts_at_gpl.coulmann.de)          #
   #                                                                        #
   ##########################################################################


EOD

QUESTION='  I understand the above warnings [YES/NO/Q]:'

echo -n "${QUESTION} "


[ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
read ANSWER
[ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"


until [ "${ANSWER}" = YES ]\
        || [ "${ANSWER}" = NO ] \
        || [ "${ANSWER}" = N ] \
        || [ "${ANSWER}" = n ] \
        || [ "${ANSWER}" = q ] \
        || [ "${ANSWER}" = Q ] ; do
   echo -n "${QUESTION} "
   [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
   read ANSWER
   [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
done

case ${ANSWER} in
  YES)
     echo -n '  accepted'
  ;;
  NO|n|N|q|Q)
     echo
     echo '  script aborted by user input'
     exit 72
  ;;
esac


FEEDBACK='################################\n  # FEEDBACK:\n
'


# load functions

function error {
  echo '[error]' ...... $1 ...... '[terminate script]'
  exit 72
}

function mark {
  [ "${NO_COLOR}" = 1 ] || echo -ne "${MARK}"
  echo -n "${1}"
  [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
}



function ask_yn {
  local QUESTION=$1
  until [ "${ANSWER}" = y ]\
          || [ "${ANSWER}" = Y ] \
          || [ "${ANSWER}" = j ] \
          || [ "${ANSWER}" = J ] \
          || [ "${ANSWER}" = n ] \
          || [ "${ANSWER}" = N ] \
          || [ "${ANSWER}" = Q ] \
          || [ "${ANSWER}" = q ] ; do
     echo -n "${QUESTION}"
     read ANSWER
  done

  case ${ANSWER} in
    y|Y|j|J)
       return
    ;;
    n|N)
       return
    ;;
    q|Q)
       [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
       echo
       echo '  script aborted by user input'
       exit 72
    ;;
  esac
}

function latex_pack_check {
  echo '  -> search LaTeX package '$1' '
  echo -n '    '
  if [ ! `kpsewhich ${1}.sty` ] ; then
    echo
    echo "  can't find package ${1}"
    echo "  on debian systems you may install apt-file"
    echo "     aptitude install apt-file"
    echo "     apt-file update"
    echo "     apt-file search ${1}.sty"
    echo "  this will show which package contains the needet LaTeX .sty file"
    echo "  on other systems, please refer to their documentation on how to "
    echo "  find matching packages."
    echo
    echo "  If you are done, rerun this script"
    echo " [unsatisfied dependencies]' ...... ${1} ...... [terminate script]"
    exit 72
  else
    echo \ \ ${OK}
  fi

}

function check_accepted_names {
  echo '  -> check for suspect characters in '${2}
  echo -n ${1} | egrep '[^-_\.!A-Za-z0-9]' && echo '  [suspect characters found] in ... '${2}' ... [terminate script]' && exit 72
}

function check_int {
  echo '  -> check for suspect characters in '${2}
  echo -n ${1} | egrep '[^0-9]' && echo '  [suspect characters found] in ... '${2}' ... [terminate script]' && exit 72
}

function create_file {
  ANSWER=0
  if [ "${1}" = ln  ] ;then
    DO=1
    echo -n '  -> try to create symbolic link '${3}
    if [ -e "${3}" ] ; then
      if [ -L "${3}" ] ; then
         if [ "`ls -l ${3} | awk '{print $10}'`" = "${2}" ]; then
           echo ' ...  symbolic link already exists, nothing to do!'
           DO=0
         else
           echo ' ...  symbolic link with different target exist!'
           ls -lah "${3}"
           echo '  you may'
           echo '      [d] delete and replace the current link'
           echo '      [m] move current link to '${3}.${TIME}.old
           echo '      [s] skip -- leave it as it is'
           echo '      [q] abort setup.sh'
           QUESTION='  what do do? [d/m/s/q]: '
           echo  -en ${QUESTION}
           [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
           read ANSWER
           [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
           until [ "${ANSWER}" = D ] \
                   || [ "${ANSWER}" = d ] \
                   || [ "${ANSWER}" = m ] \
                   || [ "${ANSWER}" = s ] \
                   || [ "${ANSWER}" = q ] ; do
              echo -n "${QUESTION}"
              read ANSWER
           done

           case ${ANSWER} in
             d)
                rm -f ${3}   || error ' unable to delete symbolic link '${3}
             ;;
             m)
                mv -f ${3} ${3}.${TIME}.old   || error ' unable to move symbolic link '${3}
             ;;
             s)
                echo '   as you decide, we leave it as it is!'
                DO=0
             ;;
             q)
                [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
                echo
                echo '  script aborted by user input'
                exit 72
             ;;
           esac
         fi
      else
        echo ' ...  file already exists where I tried to create a symbolic link!'
          ls -lah "${3}"
          echo '  you may'
          echo '      [S] show the file (exit file display with "q")'
          echo '      [m] move current file to '${3}.${TIME}.old
          echo '      [d] delete and replace the file with symbolic link'
          echo '      [s] skip -- leave it as it is'
          echo '      [q] abort setup.sh'
          QUESTION='what to do? [S/d/m/s/q]:'
          echo  -en "  ${QUESTION} "
          [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
          read ANSWER
          [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
          until [ "${ANSWER}" = S ] \
                  || [ "${ANSWER}" = d ] \
                  || [ "${ANSWER}" = m ] \
                  || [ "${ANSWER}" = s ] \
                  || [ "${ANSWER}" = q ] ; do
             echo -n "  ${QUESTION} "
             read ANSWER
          done

          case ${ANSWER} in
            S)
              echo
              echo
              less "${3}"
              echo
              echo
              create_file "${1}" "${2}" "${3}"
              return
            ;;
            m)
               mv -f ${3} ${3}.${TIME}.old   || error ' unable to move file '${3}
            ;;
            d)
               rm -f ${3}    || error ' unable to delete file '${3}
            ;;
            s)
               echo '   as you decide, we leave it as it is!'
               DO=0
            ;;
            q)
               [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
               echo
               echo '  script aborted by user input'
               exit 72
            ;;
          esac
      fi
    fi
    if [ "${DO}" = "1" ] ;then  ln -s "${2}" "${3}" || error ' failed to create symbolic link '${3} ; fi
    [ "${DO}" = "1" ] && echo \ \ ${OK}
  fi

  if [ "${1}" = cp  ] ;then
    echo -n '  -> try to copy file '${3}
       DO=1
    if [ -e "${3}" ] ; then
       echo ' ...  file already exists!'
       diff "${2}" "${3}" >/dev/null
       if [ "$?" = 0 ] ; then
         echo '   files are equal, we leave it as it is!'
         DO=0
       else
         ls -lah "${3}"
         echo '  you may'
         echo '      [D] show a diff between the new and current file'
         echo '      [m] move current file to '${3}.${TIME}.old
         echo '      [d] delete and replace with new file'
         echo '      [s] skip -- leave it as it is'
         echo '      [q] abort setup.sh'
         QUESTION='what to do? [D/m/d/s/q]:'
         echo  -en "  ${QUESTION} "
         [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
         read ANSWER
         [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
         until [ "${ANSWER}" = D ] \
                 || [ "${ANSWER}" = d ] \
                 || [ "${ANSWER}" = m ] \
                 || [ "${ANSWER}" = s ] \
                 || [ "${ANSWER}" = q ] ; do
            echo -n "  ${QUESTION} "
            read ANSWER
         done

         case ${ANSWER} in
           D)
             echo
             echo
             [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
             echo '---------------------------------------'
             [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
             diff -C 3  "${2}" "${3}"
             [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
             echo '---------------------------------------'
             [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
             echo
             echo
             create_file "${1}" "${2}" "${3}"
           ;;
           m)
              mv -f ${3} ${3}.${TIME}.old   || error ' unable to move file '${3}
           ;;
           d)
              rm -f ${3}    || error ' unable to delete file '${3}
           ;;
           s)
              echo '   as you decide, we leave it as it is!'
              DO=0
           ;;
           q)
              [ "${NO_COLOR}" = 1 ] || echo -ne "${UNMARK}"
              echo
              echo '  script aborted by user input'
              exit 72
           ;;
         esac
       fi
    fi
    if [ "${DO}" = "1" ] ;then  cp  "${2}" "${3}" || error ' failed to copy '${3} ; fi
    [ "${DO}" = "1" ] && echo \ \ ${OK}
  fi

}

function create_mydata {

  VALUE=${1}
  DB=${2}
  NODATA='  did not get a value corresponding to your template dir'

  SQL="
    SELECT regexp_replace( u1.cfg_value, E'\n' ,E'\\\\\\\\\\\\' || E'\n')
    FROM auth.user_config u1, auth.user_config u2
    WHERE u1.user_id = u2.user_id
      AND u1.cfg_key = '"${DB}"'
      AND u2.cfg_key = 'templates'
      AND u2.cfg_value = 'templates/"${TEMP_DIR}"'
   ORDER BY u1.cfg_value  DESC
   LIMIT 1;
  "
  case ${DB} in
    tel)
      PRE='Tel:'
      ;;
    fax)
      PRE='fax:'
      ;;
    co_ustid)
      if [ ! `psql --pset tuples_only -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"`"" ] ; then
        SQL="
          SELECT regexp_replace( u1.cfg_value, E'\n' ,E'\\\\\\\\\\\\' || E'\n')
          FROM auth.user_config u1, auth.user_config u2
          WHERE u1.user_id = u2.user_id
            AND u1.cfg_key = 'taxnumber'
            AND u2.cfg_key = 'templates'
            AND u2.cfg_value = 'templates/"${TEMP_DIR}"'
         ORDER BY u1.cfg_value  DESC
         LIMIT 1;
        "
        PRE='StNr.:'
      else
        PRE='UstIdNr:'
      fi
      ;;
    *)
      PRE=''
      ;;
    esac



  if [ "${2}" ] ; then
    ANSWER=`psql --pset tuples_only -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"`  || error "unable to connect to auth db"
    if [ ! "${VALUE}" ] ; then
      echo '  please fix this later'
      ANSWER=FIX_ME
    else
      echo '  found: '${ANSWER}
    fi
  else
    if [ ! "${2}" ]  && [ ${1} = "employeecountry" ] ; then
      read ANSWER
    else
      echo '  please fix this later'
      ANSWER=FIX_ME
    fi
  fi

  echo -e "\0134"'newcommand{'"\0134"${VALUE}'}{'${PRE}${ANSWER}'}' >> mydata.tex

}

function read_db_conf {

  perl -e 'use Config::Std;
           read_config "'${DB_AUTH}'.default" => my %config_default;
           my $val_default = $config_default{"authentication/database"}{'${1}'};
           read_config "'${DB_AUTH}'" => %config;
           my $val =  $config{"authentication/database"}{'${1}'} if $config{"authentication/database"}{'${1}'};
           if ( $val ) {
              print $val;
           }else{
              print $val_default;
           }'

}





# check for dependencies
echo  -n '  -> search kpsewhich '
  which kpsewhich >/dev/null
  [ "$?" = 0 ] || error 'unable find programm "kpsewhich" -- is there a propper installed LaTeX? (on debian: aptitude install texlive-base-bin)'
  echo \ \ ${OK}

if [ "${MODUL}" = "f-tex" ] ; then
  echo '  -> search LaTeX documentclass scrlttr2'
  echo -n '    '
  if [ ! `kpsewhich scrlttr2.cls` ] ; then
    echo
    echo "  can't find documentclass scrlttr2"
    echo "  on debian systems you may install it by"
    echo "     aptitude install texlive-latex-recommended"
    echo "  on other systems, please refer to their documentation how to find"
    echo "  matching packages."
    echo
    echo "  If you are done, rerun this script"
    echo " [unsatisfied dependencies]' ...... documentclass scrlttr2 ...... [terminate script]"
    exit 72
  else
    echo \ \ ${OK}
  fi
elif [ "${MODUL}" = "lp" ] ; then
  echo '  -> search LaTeX package ticket and check vor needed version '
  echo -n '    '
  HOLD_TEXINPUTS=${TEXINPUTS}
  export TEXINPUTS=''
  if [ `kpsewhich ticket.sty` ] ; then
    grep rowmode `kpsewhich ticket.sty` > /dev/null
    if [ "$?" -gt "0" ] ;then
      FILE_LIST_LP=${FILE_LIST_LP}" ticket.sty"
      echo \ \ "your version of LaTeX Package ticket does not support rowmode - we use our own ticket.sty"
      echo \ \ \ \ \ \ "ticket.sty supports option rowmode from version v0.4b"
      echo \ \ \ \ \ \ ${OK}
    fi
  else
      FILE_LIST_LP=${FILE_LIST_LP}" ticket.sty"
      echo \ \ "can't find LaTeX Package ticket, but we use our own ticket.sty because we need version => v0.4b"
      echo \ \ \ \ \ \ "ticket.sty supports option rowmode from version v0.4b"
      echo \ \ \ \ \ \ ${OK}
  fi
  export TEXINPUTS=${HOLD_TEXINPUTS}
else
  error  "no valid install modul - is the install script inside ~/templates/f-tex or ~/templates/lp ?"
fi

for PACK in `grep usepackage ${BASE_DIR}/*.tex ${BASE_DIR}/*.sty ${BASE_DIR}/*.lco |awk -F '{' '{print $2}'|awk -F '}' '{print $1}'| sort | uniq`; do
   latex_pack_check ${PACK}
done


# decide the installation target (template directory)
echo -n '  -> cd to base directory: '${BASE_DIR}' '

  cd ${BASE_DIR} || error  "unable to change directory"
  echo \ \ ${OK}



echo '  -> check if we are inside an lxo installation'

if [ ! -e ../../SL/Form.pm ] ; then

  dpkg -l | grep lx-office-erp | egrep '^ii'
  if [ "$?" = 0 ] ; then
    echo '   seams like this is a Debian-package'
    DB_AUTH='/etc/lx-office-erp/lx_office.conf'

    LXO_DETERMINE='
       /usr/lib/lx-office-erp/SL/Form.pm
       /etc/lx-office-erp/lx_office.conf.default
       /usr/share/doc/lx-office-erp/changelog
    '

    CHK_RAWNUMBER_PATCH='
       /usr/lib/lx-office-erp/SL/DO.pm
       /usr/lib/lx-office-erp/SL/IS.pm
       /usr/lib/lx-office-erp/SL/OE.pm
    '

  fi

fi

for now in ${LXO_DETERMINE} ; do
  [ -e ${now} ] || error 'missing '${now}', do not run this script outside an lx-office installation!. Is setup.sh located inside an lxo installation in templates/'${MODUL}'?'
done
echo \ \ ${OK}

if [ "${MODUL}" = "f-tex" ] ; then
  echo   '  -> search raw numbers patch '
     RAW_NUM=`egrep -oh '\{[^{]*_nofmt\}' ${CHK_RAWNUMBER_PATCH} |wc -l`

     if [ "${RAW_NUM}" -lt 20 ] ; then
       echo '  did not find the raw_number values'
       echo
       egrep -oh '\{[^{]*_nofmt\}' ${CHK_RAWNUMBER_PATCH}
       echo '  seems like you added fancy LaTeX separate and needed raw_number values are missing'
       echo '  this is already part of the dev-source code.'
       echo '  please use this script in the environment you got it from'
       error 'missing raw_number values'
     fi
    echo \ \ ${OK}
fi


if [ ${DATABASE} = 1 ] ; then

  echo  '  -> request Auth-DB '
    [ -r ${DB_AUTH} ] || [ -r ${DB_AUTH}.default ]  || error "unable to read ${DB_AUTH} or ${DB_AUTH}.default -- you must be able to read db credentials"

    export PGDATABASE=`read_db_conf db`
    check_accepted_names ${PGDATABASE} database_name
    export PGPASSWORD=`read_db_conf password`
    check_accepted_names ${PGPASSWORD} database_pw
    export PGUSER=`read_db_conf user`
    check_accepted_names ${PGUSER} database_user
    export PGPORT=`read_db_conf port`
    [ "${#PGPORT}" -lt 1 ] && PGPORT=5432
    check_int ${PGPORT} database_port
    export PGHOST=`read_db_conf host`
    [ "${#PGHOST}" -lt 1 ] && PGHOST=localhost
    check_accepted_names ${PGHOST} database_host

    SQL="
         SELECT
           substring(cfg_value from E'[^/]*$') as template_dir
         FROM auth.user_config
         WHERE cfg_key = 'templates'
         GROUP BY cfg_value ;
    "


  echo  '  -> search active template dirs '
  echo
  [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}

    psql --pset tuples_only -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"  || error "unable to connect to auth db"

  [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
  echo  '  I found the above listed template directorys in '`mark '[lxo-home]/templates'`' by requesting your user configuration.'
  echo  '  in database '`mark "${PGDATABASE}"`'.'
fi

echo  '  Type in which template directory to use (by typing in a name)'
echo  '  * if template_dir does not exist, it will be created'
echo  '  * template_dir must also be configured in your user administration'
echo  '    to make it active.'
echo
echo  -en '  type name of template dirctory: '
[ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
read TEMP_DIR
[ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}


[ "${#TEMP_DIR}" -gt 0 ] || error 'no value for template dir provided '


if [ -d "../${TEMP_DIR}" ] ; then
  MV_DIR=${TEMP_DIR}.${TIME}.old
  echo
  [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
  ls -lah ../${TEMP_DIR}
  [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
  echo
  echo '  the directory already exists and contains the above listed files'
  echo '  you can:'
  echo -e '    - move the directory to '`mark "templates/${MV_DIR}"`' and create a empty one, or'
  echo '    - install the templates in the existing directory by interactive overwriting existing files'
  echo
  ask_yn '  move templates/'${TEMP_DIR}' to templates/'${MV_DIR}'? [y/n/q]: '



  if [ "${ANSWER}" = y ] ; then
     echo  '  -> check for permission to move template directory '
     mv -i ../${TEMP_DIR} ../${MV_DIR} || error "unable to move directory "
     echo -n '  -> original directory moved to '${MV_DIR}
     echo \ \ ${OK}
  fi
  if [ "${ANSWER}" = n ] ; then
     echo  '  -> check for permission to write in template directory [lxo-home]/templates/'${TEMP_DIR}
     [ -w ../${TEMP_DIR} ] || error "no permission to write directory "
     echo \ \ ${OK}
  fi
  ANSWER=0
fi


if [ ! -d "../${TEMP_DIR}" ] ; then
  echo -n '  -> check for permission to create new template directory '
      mkdir "../"${TEMP_DIR} || error "unable to write to `echo ${PWD} | sed 's/\/'${MODUL}'$//'` -- you must be able to write in ~/templates "
  echo \ \ ${OK}
  echo -n '  -> '${TEMP_DIR}' created'
  echo \ \ ${OK}
fi

echo -n '  -> cd to template directory: '${TEMP_DIR}' '

  cd ../${TEMP_DIR} || error  "unable to change directory"
  echo \ \ ${OK}
pwd


if [ -e mydata.tex ] ;then
  echo '  -> check mydata.tex'
    grep koma ./mydata.tex && FEEDBACK=${FEEDBACK}'   # looks like a DEPRECATED mydata.tex -- please compare to f-tex/mydata.tex.example  \n'
  for now in ${MY_DATA} ; do
    grep ${now} ./mydata.tex || FEEDBACK=${FEEDBACK}'   # missing '${now}' in mydata.tex -- please compare to f-tex/mydata.tex.example  \n'
  done

  echo -e  \ \ "your current mydata.tex looks like"
  [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
  cat mydata.tex
  [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}

else
  if [ ${DATABASE} = 1 ] ; then
    # mydata voodooo goes here
    SQL="
      SELECT
       u1.cfg_value as company,
       u2.cfg_value as address,
       u3.cfg_value as tel,
       u4.cfg_value as fax,
       u5.cfg_value as texnumber,
       u6.cfg_value as co_ustid
     FROM
       auth.user_config u1,
       auth.user_config u2,
       auth.user_config u3,
       auth.user_config u4,
       auth.user_config u5,
       auth.user_config u6
     WHERE
       u1.user_id = u2.user_id  and
       u2.user_id = u3.user_id and
       u3.user_id = u4.user_id and
       u4.user_id = u5.user_id and
       u5.user_id = u6.user_id and
       u1.cfg_key = 'company' and
       u2.cfg_key = 'address' and
       u3.cfg_key = 'tel' and
       u4.cfg_key = 'fax' and
       u5.cfg_key = 'taxnumber' and
       u6.cfg_key = 'co_ustid'
     GROUP BY
       u1.cfg_value,
       u2.cfg_value,
       u3.cfg_value,
       u4.cfg_value,
       u5.cfg_value,
       u6.cfg_value
     ORDER BY
       company;
    "
#    [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
#
#      psql -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"  || error "unable to connect to auth db"
#
#    [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
    echo  '  There is no mydata.tex, we try to create it'
    echo  '  please answer the following questions'
    echo -n '  - country your company is located eg:"Deutschland" : '
    create_mydata employeecountry
    echo  '  - owner of the bankaccount for label print'
    echo  '    used for "pay on delivery (Nachnahme)"'
    echo -n '    type ~ instead of blanks eg: "Herbert~Wichtig" : '
    create_mydata labelcompanyname
    echo  '  - name of the bank for label print'
    echo  '    used for "pay on delivery (Nachnahme)"'
    echo -n '    type ~ instad of blanks eg: "Ensifera~Bank" : '
    create_mydata labelbankname
    echo  '  - bank account number for label print'
    echo  '    used for "pay on delivery (Nachnahme)"'
    echo -n '    no blanks eg: "123456789" : '
    create_mydata labelbankcode
    echo  '  - bank code (BLZ) for label print'
    echo  '    used for "pay on delivery (Nachnahme)'
    echo -n '    no blanks eg: "10010010" : '
    create_mydata labelbankaccount
    echo  '  - company name for dokuments'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "Die globalen Problemlöser" : '
    create_mydata MYfromname company
    echo  '  - company name second row for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "Gesellschaft für anderer Leute Sorgen mbH" : '
    create_mydata MYaddrsecrow
    echo  '  - legal form for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo  '    eg: "Handelsregister: HRA 123456789" : '
    echo -n '    or: "Inhaber Herbert Wichtig" : '
    create_mydata MYrechtsform
    echo  '  - company address for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo  '    multirow, type \\ as row dilimiter '
    echo -n '    eg: "Hauptstraße 5\\12345 Hier" : '
    create_mydata MYfromaddress address
    echo  '  - tel for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "Tel: +49 (0)12 3456780" : '
    create_mydata MYfromphone tel
    echo  '  - fax for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "Fax: +49 (0)12 3456781" : '
    create_mydata MYfromfax fax
    echo  '  - email for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "mail@g-problemloeser.com" : '
    create_mydata MYfromemail
    echo  '  - signatur for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo -n '    eg: "Herbert Wichtig - Geschäftsführer" : '
    create_mydata MYsignature
    echo  '  - tax number for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo  '    it is common to use ustid but if you have none'
    echo  '    type in your main tax number'
    echo  '    eg: "UstID: DE 123 456 789" : '
    echo -n '    or: "StrNr: 12/345/6789" : '
    create_mydata MYustid co_ustid
    echo  '  - bank account for documents'
    echo  '    used for invoice, sales_quotation, etc.'
    echo  '    multirow, type \\ as row delimiter '
    echo -n '    eg: "Bankverbindung\\Ensifera Bank\\Kto 1234567800\\BLZ 123 456 78" : '
    create_mydata MYfrombank

     # damn escaping -- gnarf
     perl -pi -e 's/([^\$\{])\\/$1\\\\/g' mydata.tex
     perl -pi -e 's/([\&\%])/\\$1/g' mydata.tex
  else
    cp ../f-tex/mydata.tex.example mydata.tex
    FEEDBACK=${FEEDBACK}'   # I generate a mydata.tex please edit this file to match to your needs \n'
  fi
    FEEDBACK=${FEEDBACK}'   # I generate a mydata.tex please edit this file to match to your needs \n'
fi


if [ "${MODUL}" = "f-tex" ] ; then
  # search for installed languages
  if [ ${DATABASE} = 1 ] ; then
    SQL="
    SELECT
      u1.cfg_value || ';' ||
      u2.cfg_value || ';' ||
      u3.cfg_value || ';' ||
      u4.cfg_value || ';' ||
      u5.cfg_value
    FROM
      auth.user_config u1,
      auth.user_config u2,
      auth.user_config u3,
      auth.user_config u4,
      auth.user_config u5
    WHERE
      u1.user_id = u2.user_id  and
      u2.user_id = u3.user_id and
      u3.user_id = u4.user_id and
      u4.user_id = u5.user_id and
      u1.cfg_key = 'dbname' and
      u2.cfg_key = 'dbhost' and
      u3.cfg_key = 'dbport' and
      u4.cfg_key = 'dbuser' and
      u5.cfg_key = 'dbpasswd'
    GROUP BY
      u1.cfg_value,
      u2.cfg_value,
      u3.cfg_value,
      u4.cfg_value,
      u5.cfg_value;
    "

    echo  '  -> try to determine aktive languages ....'
    echo  '  -> search database '${PGDATABASE}' to find lxo-erp databases ....'

      DBS=`psql --pset tuples_only -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"`  || error "unable to connect to auth db"

    for db in ${DBS} ; do

      PGDATABASE=`echo -n ${db} | awk -F ';' '{print $1}'`
      echo -e '  -> prepare to request db '`mark ${PGDATABASE}`
      check_accepted_names ${PGDATABASE} database_name
      PGHOST=`echo -n ${db} | awk -F ';' '{print $2}'`
      [ "${#PGHOST}" -lt 1 ] && PGHOST=localhost
      check_accepted_names ${PGHOST} database_host
      PGPORT=`echo -n ${db} | awk -F ';' '{print $3}'`
      [ "${#PGPORT}" -lt 1 ] && PGPORT=5432
      check_int ${PGPORT} database_port
      PGUSER=`echo -n ${db} | awk -F ';' '{print $4}'`
      check_accepted_names ${PGUSER} database_user
      PGPASSWORD=`echo -n ${db} | awk -F ';' '{print $5}'`
      check_accepted_names ${PGPASSWORD} database_pw
      DELCHECK=`echo -n ${db} | awk -F ';' '{print $6}'`
      [ "${#DELCHECK}" = 0 ] || error 'field delimiter conflict: there may be a ";" in one of your database definitions (db/host/port/user/pw)'
      SQL="SELECT template_code FROM language ;"
      echo \ \ ${OK}
      RES=`psql --pset tuples_only -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" -c "${SQL}"`  || error "unable to connect to db "${PGDATABASE}
      echo -e '  -> found '`mark "${RES}"`
      echo \ \ ${OK}
      LANGS=${LANGS}' '${RES}
    done

    LANGS=`echo ${LANGS} | sed 's/\ /\n/g'|sort | uniq`
    echo '  -> join language codes ...'
    echo
    echo
    [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
    echo -e '    '${LANGS}
    [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
    echo
    echo  '  I found the above listed language template_codes (see: System -> Languages -> List Languages)'
    echo  '  - you may add more template_codes by type in a [space] seperated list (e.g.: ru it fr)'
    echo  '  - or you may replace it with your own values by type in a [space] seperated list (e.g.: ru it fr)'
    ask_yn '  add template_codes? [y/n/q]: '

    if [ "${ANSWER}" = y ] ; then
       echo -n '  type [space] seperated template_code list to add to current values: '
       [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
       read TMP_CO
       [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
       echo -n '  list of template_codes is now: '
       LANGS=${LANGS}' '${TMP_CO}
       [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
       echo -e '    '${LANGS}
       [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
       echo \ \ ${OK}
    fi
    ANSWER=0

    ask_yn '  replace the current template_codes? [y/n/q]: '

    if [ "${ANSWER}" = y ] ; then
       echo -n '  type [space] seperated template_code list to replace current values: '
       [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
       read TMP_CO
       [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
       echo -n '  list of template_codes is now: '
       LANGS=${TMP_CO}
       [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
       echo -e '    '${LANGS}
       [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
       echo \ \ ${OK}
    fi
    ANSWER=0
  else
     echo -n '  type [space] seperated template_code list (see: System -> Languages -> List Languages eg: de en fr): '
     [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
     read TMP_CO
     [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
     echo -n '  list of template_codes is now: '
     LANGS=${TMP_CO}
     [ "${NO_COLOR}" = 1 ] || echo -ne ${MARK}
     echo -e '    '${LANGS}
     [ "${NO_COLOR}" = 1 ] || echo -ne ${UNMARK}
     echo \ \ ${OK}
  fi

  echo
  echo
  echo -e '  your current language template_codes are: '`mark "${LANGS}"`
  echo
  echo

  # copy files and create links



  for now in ${FILE_LIST_FTEX} ; do
    create_file cp ../f-tex/${now} ${now}
  done

  for now in ${LANGS} ; do
    echo -n '  -> check if language code '${now}' is present in translations.tex'
    egrep '^[^%]*\\IfEndWith{\\docname}{_'${now}'}' translations.tex  > /dev/null
    if [ "$?" -gt 0 ] ;then
      HINT='  edit '${TEMP_DIR}'/translations.tex -- no representation of template_code '${now}
      echo '  [warning] '${HINT}
      FEEDBACK=${FEEDBACK}'   # '${HINT}'\n'
    fi
    echo \ \ ${OK}
  done


  for doc in ${DOC_TYPE_FTEX} ; do
    create_file ln  ./letter.tex ./${doc}.tex
    for now in ${LANGS} ; do
      create_file ln ./letter.tex  ./${doc}_${now}.tex
    done
  done

  create_file ln  ./sample_head.pdf ./letter_head.pdf
  create_file ln  ./sample.lco ./letter.lco

fi



if [ "${MODUL}" = "lp" ] ; then

  for now in ${FILE_LIST_LP} ; do
    create_file cp ../lp/${now} ${now}
  done

fi

echo
echo
echo -en ' '${FEEDBACK}
echo -e ' ################################'
echo
echo '  If there are warnings listed in the feedback box above'
echo '  this is totally ok if you know what you do'
echo
echo '  done -> enjoy'
echo '  ### please check "settings" in '`pwd`'letter.lco '


# company
# address
# co_ustid
# email
# taxnumber
# tel
# fax
