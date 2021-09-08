#!/bin/sh
# 
# This script retrive configs in json format and extract docker images.
#
# Script executed in two stages:
# 1.  At the beginning need to scan initial configuration before installing kubeflow.
# 2.  On second stage script scanning configuration with the kubeflow installed. As result will kubeflow_images.txt file will be created.
#
# You can re-scan kubeflow any time you need. (use '-scan_kf' flag)
#

#
# Docker images command:
#    docker images --all|awk '{print $1}' | grep -v ^REPOSITORY > docker_iamges.txt

TMP_BEFORE_INSTALL="namespaces_before.txt"
TMP_AFTER_INSTALL="namespaces_after.txt"
KUBEFLOW_NAMESPACES=""
FILE_IMAGES_LIST="images.txt"
FILE_CM_LIST="cm_images.txt"
FILE_KUBEFLOW_NS_LIST="kubeflow_ns_list.txt"
PY_SCRIPT="$(dirname $0)/kf_parse.py"

collect_ns(){
    echo "Collecting NS..."
    #kubectl get all --all-namespaces |grep -v ^NAMESPACE|awk '{print $1}'|sort|sed  /^$/d|uniq > $1
    #kubectl get ns -A  > $1
    kubectl get ns -A -ojsonpath="{..name}" |tr -s '[[:space:]]' '\n' > $1
}

#
# Fetch and install kubeflow
#
install_kubeflow(){
    git clone https://github.com/HPEEzmeral/kubeflow.git
    cd kubeflow
    git checkout kf1.3
    ./bootstrap/install.sh
    cd ..
}

if [ "$DISABLE_ISTIO" = "true" ]; then
    echo ISTIO was disabled
    KUBEFLOW_NAMESPACES=`echo $KUBEFLOW_NAMESPACES|sed s/istio-system//g`
fi

scan(){
    if [ -f $TMP_BEFORE_INSTALL ]; then
        echo "System already scanned, file exists: $TMP_BEFORE_INSTALL, use '$0 scan_kf' to continue "
        echo "Please clear initial configuration or delete txt files manually: $0 clear"
    else
    collect_ns $TMP_BEFORE_INSTALL
    fi
}

scan_kf(){
    collect_ns $TMP_AFTER_INSTALL
    #
    # 4) Determine new namespaces
    #
    KUBEFLOW_NAMESPACES=`diff $TMP_BEFORE_INSTALL $TMP_AFTER_INSTALL |grep ^\>|awk '{print $2}'`
    echo $KUBEFLOW_NAMESPACES | tr -s '[[:space:]]' '\n' | sort | uniq > $FILE_KUBEFLOW_NS_LIST

    #
    # Result output
    #
    echo "" > $FILE_IMAGES_LIST
    echo "" > $FILE_CM_LIST
    echo "" > images_describe.txt

    for ns in `cat $FILE_KUBEFLOW_NS_LIST`
    do
        echo Retrieve NS: $ns
        kubectl get all -n $ns -o jsonpath="{..image}" |tr -s '[[:space:]]' '\n' |sort |uniq >> $FILE_IMAGES_LIST
        #
        # Another way to get iamge list
        #
        #kubectl describe cm -n $ns |grep "image" | awk '{print $2}'|sort|sed  /^$/d|uniq -c >> images_describe.txt
      #kubectl describe cm -n $ns |grep -i "image" >> images_describe.txt
      if ! [ -f cm-$ns.json ]; then
        echo Get ConfigMap: $ns
        kubectl get cm -n $ns -ojson > cm-$ns.json
      fi
      python3 $PY_SCRIPT cm-$ns.json >> $FILE_CM_LIST

    done
    cat $FILE_CM_LIST $FILE_IMAGES_LIST | sort|sed  /^$/d|uniq -c > kubeflow_images.txt
}

clear(){
    #
    # Cleanup initial data (first scan)
    #
    rm -f $TMP_BEFORE_INSTALL
}

clear_kf(){
    #
    # Cleanup kubeflow data
    #
    rm -f $TMP_AFTER_INSTALL
    rm -f $FILE_CM_LIST
    if [ -f "$FILE_KUBEFLOW_NS_LIST" ]; then
    for ns in `cat $FILE_KUBEFLOW_NS_LIST`; do
      echo "Remove $ns.json"
      rm -f ${ns}.json
    done
    fi
    rm -f $FILE_KUBEFLOW_NS_LIST
    rm -f kubeflow_images.txt
  rm -f $FILE_IMAGES_LIST
}


case $1 in
        "scan")
                #
                # Get namespace list before kubeflow installation
                #
                        scan
                ;;
        "scan_kf")
                #
                # Get namespace list after kubeflow installation
                #
                scan_kf
                ;;
        "clear_kf")
                #
                # Clear namespace list after kubeflow installation
                #
                clear_kf
                ;;
        "clear")
                clear
                clear_kf
                ;;
        *)
                echo "\nUsage: "
                echo "  1. Scan system before kubeflow installed with command: '$0 scan'"
                echo "  2. Install kubeflow"
                echo "  3. Scan system after kubeflow installed: $0 scan_kf\n"
                echo "$0 [clear | clear_kf | scan | scan_kf]\n"
                ;;
esac
