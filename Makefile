# Copyright 2013, Big Switch Networks, Inc.
#
# LoxiGen is licensed under the Eclipse Public License, version 1.0 (EPL), with
# the following special exception:
#
# LOXI Exception
#
# As a special exception to the terms of the EPL, you may distribute libraries
# generated by LoxiGen (LoxiGen Libraries) under the terms of your choice, provided
# that copyright and licensing notices generated by LoxiGen are not altered or removed
# from the LoxiGen Libraries and the notice provided below is (i) included in
# the LoxiGen Libraries, if distributed in source code form and (ii) included in any
# documentation for the LoxiGen Libraries, if distributed in binary form.
#
# Notice: "Copyright 2013, Big Switch Networks, Inc. This library was generated by the LoxiGen Compiler."
#
# You may not use this file except in compliance with the EPL or LOXI Exception. You may obtain
# a copy of the EPL at:
#
# http://www.eclipse.org/legal/epl-v10.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# EPL for the specific language governing permissions and limitations
# under the EPL.

# Available targets: all, c, python, clean

# This Makefile is just for convenience. Users that need to pass additional
# options to loxigen.py are encouraged to run it directly.

# Where to put the generated code.
LOXI_OUTPUT_DIR = loxi_output

# Generated files depend on all Loxi code and input files
LOXI_PY_FILES=$(shell find . \( -name loxi_output -prune \
                             -o -name templates -prune \
                             -o -name tests -prune \
                             -o -name '*' \
                           \) -a -name '*.py')
LOXI_TEMPLATE_FILES=$(shell find */templates -type f -a \
                                 \! \( -name '*.cache' -o -name '.*' \))
INPUT_FILES = $(wildcard openflow_input/*)
TEST_DATA = $(shell find test_data -name '*.data')
OPENFLOWJ_WORKSPACE = openflowj-loxi

all: c python

c: .loxi_ts.c

.loxi_ts.c: ${LOXI_PY_FILES} ${LOXI_TEMPLATE_FILES} ${INPUT_FILES ${TEST_DATA}
	./loxigen.py --install-dir=${LOXI_OUTPUT_DIR} --lang=c
	touch $@

python: .loxi_ts.python

.loxi_ts.python: ${LOXI_PY_FILES} ${LOXI_TEMPLATE_FILES} ${INPUT_FILES} ${TEST_DATA}
	./loxigen.py --install-dir=${LOXI_OUTPUT_DIR} --lang=python
	touch $@

python-doc: python
	rm -rf ${LOXI_OUTPUT_DIR}/pyloxi-doc
	mkdir -p ${LOXI_OUTPUT_DIR}/pyloxi-doc
	cp -a py_gen/sphinx ${LOXI_OUTPUT_DIR}/pyloxi-doc/input
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi sphinx-apidoc -o ${LOXI_OUTPUT_DIR}/pyloxi-doc/input ${LOXI_OUTPUT_DIR}/pyloxi
	sphinx-build ${LOXI_OUTPUT_DIR}/pyloxi-doc/input ${LOXI_OUTPUT_DIR}/pyloxi-doc
	rm -rf ${LOXI_OUTPUT_DIR}/pyloxi-doc/input
	@echo "HTML documentation output to ${LOXI_OUTPUT_DIR}/pyloxi-doc"

java: .loxi_ts.java
	mkdir -p ${OPENFLOWJ_WORKSPACE}
	ln -sf ../java_gen/pre-written/pom.xml ${OPENFLOWJ_WORKSPACE}/pom.xml
	ln -sf ../java_gen/pre-written/src ${OPENFLOWJ_WORKSPACE}/src
	rsync --checksum --delete -rv ${LOXI_OUTPUT_DIR}/openflowj/src/ ${OPENFLOWJ_WORKSPACE}/gen-src

.loxi_ts.java: ${LOXI_PY_FILES} ${LOXI_TEMPLATE_FILES} ${INPUT_FILES} ${TEST_DATA}
	./loxigen.py --install-dir=${LOXI_OUTPUT_DIR} --lang=java
	touch $@

java-eclipse: java
	cd ${OPENFLOWJ_WORKSPACE} && mvn eclipse:eclipse
	# Unfortunately, mvn eclipse:eclipse resolves the symlink, which doesn't work with eclipse
	cd ${OPENFLOWJ_WORKSPACE} && perl -pi -e 's{<classpathentry kind="src" path="[^"]*/java_gen/pre-written/src/}{<classpathentry kind="src" path="src/}' .classpath

clean:
	rm -rf loxi_output # only delete generated files in the default directory
	rm -f loxigen.log loxigen-test.log .loxi_ts.c .loxi_ts.python .loxi_ts.java

debug:
	@echo "LOXI_OUTPUT_DIR=\"${LOXI_OUTPUT_DIR}\""
	@echo
	@echo "LOXI_PY_FILES=\"${LOXI_PY_FILES}\""
	@echo
	@echo "LOXI_TEMPLATE_FILES=\"${LOXI_TEMPLATE_FILES}\""
	@echo
	@echo "INPUT_FILES=\"${INPUT_FILES}\""

check:
	./utest/test_parser.py
	./utest/test_frontend.py
	./utest/test_test_data.py
	./utest/test_generic_utils.py

check-py: python
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi:. python py_gen/tests/generic_util.py
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi:. python py_gen/tests/of10.py
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi:. python py_gen/tests/of11.py
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi:. python py_gen/tests/of12.py
	PYTHONPATH=${LOXI_OUTPUT_DIR}/pyloxi:. python py_gen/tests/of13.py

check-c: c
	make -C ${LOXI_OUTPUT_DIR}/locitest
	${LOXI_OUTPUT_DIR}/locitest/locitest

check-java: java
	cd ${OPENFLOWJ_WORKSPACE} && mvn compile test-compile test

package-java: java
	cd ${OPENFLOWJ_WORKSPACE} && mvn package

deploy-java: java
	cd ${OPENFLOWJ_WORKSPACE} && mvn deploy

install-java: java
	cd ${OPENFLOWJ_WORKSPACE} && mvn install


pylint:
	pylint -E ${LOXI_PY_FILES}

.PHONY: all clean debug check pylint c python
