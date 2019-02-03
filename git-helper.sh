#!/bin/bash


# author : suxiong.sx


PROGRAM=$0
ORDER=$1

RC_NORMAL=0

RC_UNKNOW_REASON=1
RC_PARAM_NOT_ENOUGH=2
RC_ILLEGAL_ORDER=3

RC_ILLEGAL_CHOOSE=4

RC_CO_FAIL=5
RC_LOCAL_DELETE_FAIL=6

RC_MERGE_FAIL=11

RC_ADD_NO_FIELS=21
RC_ADD_FAIL=22
RC_ADD_NO_FIELS=21

RC_CI_FAIL=31


ORIGIN_PREFIX="origin/"
FEATURE_PREFIX="feature/"
START_POINT_PREFIX=$ORIGIN_PREFIX$FEATURE_PREFIX

usage(){
    echo "Usage  :  $PROGRAM   co|lco|add|ci|merge|lrm|lb|rfb"
    if [ $# -eq 0 ]; then
	exit $RC_UNKNOW_REASON
    else
	exit $1
    fi
}

if [ $# -lt 1 ]; then
    usage $RC_PARAM_NOT_ENOUGH
fi

local_branch(){
    local_branch=$( \
	  git branch -a \
	    | awk     '{print substr($0, 3, length-3+1)}'  \
	    | awk -F/ '"remotes"!=$1 {print $1}' \
	)
    echo $local_branch
}

remote_feature_branch(){
    remote_feature_branch=$( \
	   git branch -a \
	    | awk     '"*"!=substr($0, 1, 1){print substr($0, 3, length-3+1)}'  \
	    | awk -F/ 'index($0, "->")==0 && "remotes"==$1 && "origin"==$2 && "feature"==$3{print $4}' \
	 )
    echo $remote_feature_branch
}

remote_feature_branch_by_array(){

    remote_feature_branch=$(remote_feature_branch)

    start_point_prefix=$START_POINT_PREFIX
    j=1
    for i in $remote_feature_branch; do
	array_feature_branch[j++]=$start_point_prefix$i
    done;

    echo ${array_feature_branch[*]}

}


local_branch_un_attach_by_array(){

    local_branch=$(local_branch)

    remote_feature_branch=$(remote_feature_branch)

    j=1
    for i in $remote_feature_branch; do

	co_already=0
	for k in $local_branch; do
	        if [ x"$i" == x"$k" ]; then
		    co_already=1
		    break
		        fi
		done
	if [ $co_already -eq 1 ]; then
	        continue
		fi

	array_feature_branch[j++]=$FEATURE_PREFIX$i

    done;

    echo ${array_feature_branch[*]}

}

local_branch_array(){

    local_branch=$(local_branch)

    j=1
    for i in $local_branch; do

	local_branch_array[j++]=$i

    done;

    echo ${local_branch_array[*]}

}

print_array(){

    i=0
    echo "========================================="
    while [ $# -gt 0 ]; do
	echo $i, $1
	((i++))
	shift
    done
    echo "========================================="

    #
    # n_br=${#array[@]}
    # echo $n_br
    # echo "========================================="
    # for i in ${array[*]}; do
    # echo $i
    # done;
    # echo "========================================="

}

git_co(){

    array=($(local_branch_un_attach_by_array))
    ### array choose start
    print_array "${array[@]}"
    promot="Please choose one branch to check out :"
    read -p "$promot" pick
    value=${array[$pick]}

    if [ -z $value ]; then
	echo "Illegal choose, $pick"
	exit $RC_ILLEGAL_CHOOSE
    fi
    ### array choose end

    br_choose=$value

    start_point=$ORIGIN_PREFIX$br_choose
    #echo $br_choose, $start_point
    co_ret=$(git checkout -b $br_choose $start_point)
    if [ $? -ne 0 ];then
	exit $RC_CO_FAIL
    else
	echo "git co success, local=$br_choose, remote=$start_point"
    fi
}

git_merge(){

    array=($(remote_feature_branch_by_array))
    array[${#array[@]}]=$ORIGIN_PREFIX"master"

    ### array choose start
    print_array "${array[@]}"
    promot="Please choose one branch to check out :"
    read -p "$promot" pick
    value=${array[$pick]}

    if [ -z $value ]; then
	echo "Illegal choose, $pick"
	exit $RC_ILLEGAL_CHOOSE
    fi
    ### array choose end

    br_choose=$value

    merge_ret=$(git merge $br_choose)
    if [ $? -ne 0 ];then
	echo "git merge fail, $merge_ret"
	exit $RC_MERGE_FAIL
    else
	echo "git merge success, remote=$br_choose"
    fi
}

git_add_dir(){

    add_dirs=$( \
	   git status -s| \
	   awk '(substr($0, 1, 1)=="?" && substr($0, 2, 1)=="?") \
       && $0~/\/$/ \
       {print substr($0, 4, length - 4 + 1)}' \
	   )

    add_dirs_str=""
    for i in $add_dirs; do
	add_dirs_str=$i"-"${add_dirs_str}
	array_add_dirs[j++]=$i
    done;

    if [ ! -z $add_dirs_str ]; then

	j=1
	for i in $add_dirs; do
	        array_add_dirs[j++]=$i
		done;

	print_array "${array_add_dirs[@]}"
	promot="Add these dirs ? (yes or no):"

	read -p "$promot" choose
	if [ x"$choose" != x"yes" ]; then
	        echo "Add dirs cancel"
		    exit $RC_NORMAL
		    fi

	add_dirs_ret=$(git add $add_dirs)
	if [ $? -ne 0 ];then
	        echo "git add dir fail, $add_dirs_ret"
		    exit $RC_ADD_FAIL
		    fi
    fi
}

git_add(){

    # add dir
    git_add_dir

    # add file
    add_files=$( \
	   git status -s| \
	   awk '((substr($0, 1, 1)=="?" && substr($0, 2, 1)=="?") || (substr($0, 1, 1)==" " && substr($0, 2, 1)=="M") || (substr($0, 1, 1)=="A" && substr($0, 2, 1)==" ")) \
       && $0~/\.java$|\.xml$|\.sh$|\.json$/ \
       {print substr($0, 4, length - 4 + 1)}' \
       )

    if [ -z "$add_files" ] ; then
	echo "No file to add"
	exit $RC_ADD_NO_FIELS
    fi

    j=1
    for i in $add_files; do
	array_add_files[j++]=$i
    done;

    print_array "${array_add_files[@]}"
    promot="Add these files ? (yes or no):"

    read -p "$promot" choose
    if [ x"$choose" != x"yes" ]; then
	echo "Add files cancel"
	exit $RC_NORMAL
    fi

    add_ret=$(git add $add_files)
    if [ $? -ne 0 ];then
	echo "git add fail, $add_rete"
	exit $RC_ADD_FAIL
    else
	echo "git add success"
    fi
}

git_commit_push(){

    default_msg="Commit By Git-Helper"
    promot="Please input commit msg ( $default_msg ):"

    read -p "$promot" commit_msg

    if [ -z $commit_msg ]; then
	commit_msg=$default_msg
    fi

    commit_ret=$(git commit -m "$commit_msg")
    if [ $? -ne 0 ];then
	echo "git commit fail, $commit_ret"
	exit $RC_CI_FAIL
    fi

    push_ret=$(git push)
    if [ $? -ne 0 ];then
	echo "git push fail, $push_ret"
	exit $RC_CI_FAIL
    else
	echo "git push success, msg : \"$commit_msg\""
    fi


}

git_local_lco(){

    array=($(local_branch_array))
    ### array choose start
    print_array "${array[@]}"

    promot="Please choose one branch to check out :"
    read -p "$promot" pick
    value=${array[$pick]}

    if [ -z $value ]; then
	echo "Illegal choose, $pick"
	exit $RC_ILLEGAL_CHOOSE
    fi
    ### array choose end

    br_choose=$value
    local_rm_ret=$(git checkout $br_choose)
    if [ $? -ne 0 ];then
	exit $RC_LOCAL_DELETE_FAIL
    else
	echo "git remove local branch  success, local=$br_choose"
    fi

}

git_local_rm(){

    array=($(local_branch_array))
    ### array choose start
    print_array "${array[@]}"

    promot="Please choose one branch to check out :"
    read -p "$promot" pick
    value=${array[$pick]}

    if [ -z $value ]; then
	echo "Illegal choose, $pick"
	exit $RC_ILLEGAL_CHOOSE
    fi
    ### array choose end

    br_choose=$value
    local_rm_ret=$(git branch -d $br_choose)
    if [ $? -ne 0 ];then
	exit $RC_LOCAL_DELETE_FAIL
    else
	echo "git remove local branch  success, local=$br_choose"
    fi

}
# main

## check out
if [ x"$ORDER" == x"co" ]; then
    git_co
elif [ x"$ORDER" == x"lco" ]; then
    git_local_lco
## add
elif [ x"$ORDER" == x"add" ]; then
    git_add
## commit-push
elif [ x"$ORDER" == x"cp" ]; then
    git_commit_push
## add-commit-push
elif [ x"$ORDER" == x"ci" ]; then
    git_add
    git_commit_push
## merge
elif [ x"$ORDER" == x"merge" ]; then
    git_merge
## delete
elif [ x"$ORDER" == x"lrm" ]; then
    git_local_rm
## for search
elif [ x"$ORDER" == x"lb" ]; then
    l_b_array=(`local_branch_array`)
    print_array "${l_b_array[@]}"
elif [ x"$ORDER" == x"rfb" ]; then
    r_f_b_array=(`remote_feature_branch_by_array`)
    print_array "${r_f_b_array[@]}"
else
    echo "Illegal order : $ORDER, please check your command"
    exit $RC_ILLEGAL_ORDER
fi
