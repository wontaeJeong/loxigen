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

##
# @brief Utilities related to parsing C files
#
import re
import sys
import os
import of_g

def type_dec_to_count_base(m_type):
    """
    Resolve a type declaration like uint8_t[4] to a count (4) and base_type
    (uint8_t)

    @param m_type The string type declaration to process
    """
    count = 1
    chk_ar = m_type.split('[')
    if len(chk_ar) > 1:
        count_str = chk_ar[1].split(']')[0]
        if count_str in of_g.ofp_constants:
            count = of_g.ofp_constants[count_str]
        else:
            count = int(count_str)
        base_type = chk_ar[0]
    else:
        base_type = m_type
    return count, base_type

def comment_remover(text):
    """
    Remove C and C++ comments from text
    @param text Possibly multiline string of C code.

    http://stackoverflow.com/questions/241327/python-snippet-to-remove-c-and-c-comments
    """

    def replacer(match):
        s = match.group(0)
        if s.startswith('/'):
            return ""
        else:
            return s
    pattern = re.compile(
        r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"',
        re.DOTALL | re.MULTILINE
    )
    return re.sub(pattern, replacer, text)


def clean_up_input(text):
    text = comment_remover(text)
    text_lines = text.splitlines()
    all_lines = []
    for line in text_lines:
        line = re.sub("\t", " ", line) # get rid of tabs
        line = re.sub(" +$", "", line) # Strip trailing blanks
        if len(line):
            all_lines.append(line)
    text = "\n".join(all_lines)
    return text

def extract_structs(contents):
    """
    Extract the structures from raw C code input
    @param contents The text of the original C code
    """
    contents = clean_up_input(contents)
    struct_list = re.findall("struct .* \{[^}]+\};", contents)
    return struct_list

def extract_enums(contents):
    """
    Extract the enums from raw C code input
    @param contents The text of the original C code
    @return An array where each entry is an (unparsed) enum instance
    """
    contents = clean_up_input(contents)
    enum_list = re.findall("enum .* \{[^}]+\};", contents)
    return enum_list

def extract_enum_vals(enum):
    """
    From a C enum, return a pair (name, values)
    @param enum The C syntax enumeration
    @returns (name, values), see below

    name is the enum name
    values is a list pairs (<ident>, <value>) where ident is the
    identifier and value is the associated value.

    The values are integers when possible, otherwise strings
    """

    rv_list = []
    name = re.search("enum +(\w+)", enum).group(1)
    lines = " ".join(enum.split("\n"))
    body = re.search("\{(.+)\}", lines).group(1)
    entries = body.split(",")
    previous_value = -1
    for m in entries:
        if re.match(" *$", m): # Empty line
            continue
        # Parse with = first
        search_obj = re.match(" +(\w+) *= *(.*) *", m)
        if search_obj:  # Okay, had =
            e_name = search_obj.group(1)
            e_value = search_obj.group(2)
        else: # No equals
            search_obj = re.match(" +(\w+)", m)
            if not search_obj:
                sys.stderr.write("\nError extracting enum for %s, member %s\n"
                                 % (name, m))
                sys.exit(1)
            e_name = search_obj.group(1)
            e_value = previous_value + 1
        rv_list.append([e_name, e_value])

        if type(e_value) is type(0):
            previous_value = e_value
        else:
            try:
                previous_value = int(e_value, 0)
            except ValueError:
                pass
    return (name, rv_list)

def extract_defines(contents):
    """
    Returns a list of pairs (<identifier>, <value>) where
    #define <ident> <value> appears in the file
    """
    rv_list = []
    contents = clean_up_input(contents)
    define_list = re.findall("\#define +[^ ]+ .*\n", contents, re.M)
    for entry in define_list:
        match_obj = re.match("#define +([^ ]+) +(.+)$", entry)
        rv_list.append([match_obj.group(1),match_obj.group(2)])
    return rv_list
        
