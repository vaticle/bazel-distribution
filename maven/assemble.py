#!/usr/bin/env python

#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

from __future__ import print_function

import sys
import zipfile
import subprocess as sp
from operator import attrgetter
from xml.etree import ElementTree


_, output_jar_path, input_jar_path, pom_file_path = sys.argv

namespace = { 'namespace': 'http://maven.apache.org/POM/4.0.0' }
root = ElementTree.parse(pom_file_path).getroot()
group_id = root.find('namespace:groupId', namespace)
artifact_id = root.find('namespace:artifactId', namespace)
version = root.find('namespace:version', namespace)
if group_id is None:
    raise Exception("Could not get groupId from pom.xml")
if artifact_id is None:
    raise Exception("Could not get artifactId from pom.xml")
if version is None:
    raise Exception("Could not get version from pom.xml")


directory_inside_jar = 'META-INF/maven/{}/{}/'.format(group_id.text, artifact_id.text)

# Copy input file to output file
with open(input_jar_path, 'rb') as input_jar:
    with open(output_jar_path, 'wb') as output_jar:
        output_jar.write(input_jar.read())

with zipfile.ZipFile(output_jar_path, 'a') as output_jar:
    # Update the JAR contents to simulate Maven structure

    # pom.xml
    with open(pom_file_path) as pom_file:
        output_jar.writestr(directory_inside_jar + 'pom.xml', pom_file.read())

    # pom.properties
    output_jar.writestr(directory_inside_jar + 'pom.properties', '\n'.join((
        "#Generated by Bazel",
        "#{}".format(sp.check_output('date', env={'LANG': 'C'}).strip()),
        "version={}".format(version.text),
        "groupId={}".format(group_id.text),
        "artifactId={}".format(artifact_id.text)
    )))
