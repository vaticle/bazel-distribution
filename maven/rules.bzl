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

_DEPLOY_MAVEN_RELEASE_REPO_KEY = "DEPLOY_MAVEN_RELEASE_REPO"

def _parse_maven_coordinates(coordinates_string, enforce_version_template=True):
    coordinates = coordinates_string.split(':')
    # Maven coordinates in the bazel ecosystem can include more than three fields.
    # The group and artifact IDs are always the first 2 and the version is always the last field.
    group_id, artifact_id = coordinates[0:2]
    version = coordinates[-1]
    if enforce_version_template and version != "{pom_version}":
        fail("should assign {pom_version} as Maven version via `tags` attribute")
    return struct(
        group_id = group_id,
        artifact_id = artifact_id,
        version = version
    )

def _generate_version_file(ctx):
    version_file = ctx.file.version_file
    if not ctx.attr.version_file:
        version_file = ctx.actions.declare_file(ctx.attr.name + "__do_not_reference.version")
        version = ctx.var.get("version", "0.0.0")

        ctx.actions.run_shell(
            inputs = [],
            outputs = [version_file],
            command = "echo -n {} > {}".format(version, version_file.path),
        )
    return version_file

def _generate_pom_file(ctx, version_file):
    overridden = []
    override_dependencies = []
    for target, overrides in ctx.attr.platform_overrides.items():
        overridden_dependency = target[JarInfo].name
        overridden.append(overridden_dependency)
        for maven_coordinate in json.decode(overrides):
            override_dependencies.append(maven_coordinate)

    pom_deps = [] + override_dependencies
    for pom_dependency in [dep for dep in ctx.attr.target[JarInfo].deps.to_list() if dep.type == 'pom']:
        pom_dependency = pom_dependency.maven_coordinates
        if pom_dependency in overridden:
            continue
        if pom_dependency == ctx.attr.target[JarInfo].name:
            continue
        pom_dependency_coordinates = _parse_maven_coordinates(pom_dependency, False)
        pom_dependency_artifact = pom_dependency_coordinates.group_id + ":" + pom_dependency_coordinates.artifact_id
        pom_dependency_version = pom_dependency_coordinates.version

        version = ctx.attr.version_overrides.get(pom_dependency_artifact, pom_dependency_version)
        pom_deps.append(pom_dependency_artifact + ":" + version)

    maven_coordinates = _parse_maven_coordinates(ctx.attr.target[JarInfo].name)
    pom_file = ctx.actions.declare_file("{}_pom.xml".format(ctx.attr.name))

    ctx.actions.run(
        executable = ctx.executable._pom_generator,
        inputs = [version_file, ctx.file.workspace_refs],
        outputs = [pom_file],
        arguments = [
            "--project_name=" + ctx.attr.project_name,
            "--project_description=" + ctx.attr.project_description,
            "--project_url=" + ctx.attr.project_url,
            "--license=" + ctx.attr.license,
            "--scm_url=" + ctx.attr.scm_url,
            "--developers=" + json.encode(ctx.attr.developers),
            "--target_group_id=" + maven_coordinates.group_id,
            "--target_artifact_id=" + maven_coordinates.artifact_id,
            "--target_deps_coordinates=" + ";".join(pom_deps),
            "--version_file=" + version_file.path,
            "--output_file=" + pom_file.path,
            "--workspace_refs_file=" + ctx.file.workspace_refs.path,
        ],
    )

    return pom_file

def _generate_class_jar(ctx, pom_file):
    target = ctx.attr.target
    maven_coordinates = _parse_maven_coordinates(target[JarInfo].name)

    jar = None
    if hasattr(target, "files") and target.files.to_list() and target.files.to_list()[0].extension == "jar":
        jar = target[JavaInfo].outputs.jars[0].class_jar
    else:
        fail("Could not find JAR file to deploy in {}".format(target))

    output_jar = ctx.actions.declare_file("{}-{}.jar".format(maven_coordinates.group_id, maven_coordinates.artifact_id))

    class_jar_deps = [dep.class_jar for dep in target[JarInfo].deps.to_list() if dep.type == 'jar']
    class_jar_paths = [jar.path] + [target.path for target in class_jar_deps]

    ctx.actions.run(
        executable = ctx.executable._jar_assembler,
        inputs = [jar, pom_file] + class_jar_deps,
        outputs = [output_jar],
        arguments = [
            "--group-id=" + maven_coordinates.group_id,
            "--artifact-id=" + maven_coordinates.artifact_id,
            "--pom-file=" + pom_file.path,
            "--jars=" + ";".join(class_jar_paths),
            "--output=" + output_jar.path,
        ],
    )

    return output_jar

def _generate_source_jar(ctx):
    target = ctx.attr.target
    maven_coordinates = _parse_maven_coordinates(target[JarInfo].name)

    srcjar = None

    if hasattr(target, "files") and target.files.to_list() and target.files.to_list()[0].extension == "jar":
        for output in target[JavaInfo].outputs.jars:
            if output.source_jar and (output.source_jar.basename.endswith("-src.jar") or output.source_jar.basename.endswith("-sources.jar")):
                srcjar = output.source_jar
                break
    else:
        fail("Could not find JAR file to deploy in {}".format(target))

    if not srcjar:
        return None

    output_jar = ctx.actions.declare_file("{}-{}-sources.jar".format(maven_coordinates.group_id, maven_coordinates.artifact_id))

    source_jar_deps = [dep.source_jar for dep in target[JarInfo].deps.to_list() if dep.type == 'jar' and dep.source_jar]
    source_jar_paths = [srcjar.path] + [target.path for target in source_jar_deps]

    ctx.actions.run(
        executable = ctx.executable._jar_assembler,
        inputs = [srcjar] + source_jar_deps,
        outputs = [output_jar],
        arguments = [
            "--jars=" + ";".join(source_jar_paths),
            "--output=" + output_jar.path,
        ],
    )

    return output_jar

def _assemble_maven_impl(ctx):
    version_file = _generate_version_file(ctx)
    pom_file = _generate_pom_file(ctx, version_file)
    class_jar = _generate_class_jar(ctx, pom_file)
    source_jar = _generate_source_jar(ctx)

    output_files = [pom_file, class_jar]
    if source_jar:
        output_files.append(source_jar)

    return [
        DefaultInfo(files = depset(output_files)),
        MavenDeploymentInfo(jar = class_jar, pom = pom_file, srcjar = source_jar)
    ]

def find_maven_coordinates(target, tags):
    _TAG_KEY_MAVEN_COORDINATES = "maven_coordinates="
    for tag in tags:
        if tag.startswith(_TAG_KEY_MAVEN_COORDINATES):
            coordinates = tag[len(_TAG_KEY_MAVEN_COORDINATES):]
            target_is_in_root_workspace = target.label.workspace_root == ""
            if coordinates.endswith("{pom_version}") and not target_is_in_root_workspace:
                coordinates = coordinates.replace("{pom_version}", target.label.workspace_root.replace("external/", ""))
            return coordinates

JarInfo = provider(
    fields = {
        "name": "The name of a the JAR (Maven coordinates)",
        "deps": "The list of dependencies of this JAR. A dependency may be of two types, POM or JAR.",
    },
)

def _aggregate_dependency_info_impl(target, ctx):
    tags = getattr(ctx.rule.attr, "tags", [])
    deps = getattr(ctx.rule.attr, "deps", [])
    runtime_deps = getattr(ctx.rule.attr, "runtime_deps", [])
    exports = getattr(ctx.rule.attr, "exports", [])
    deps_all = deps + exports + runtime_deps

    maven_coordinates = find_maven_coordinates(target, tags)
    dependencies = []

    # depend via POM
    if maven_coordinates:
        dependencies = [struct(
            type = "pom",
            maven_coordinates = maven_coordinates
        )]
    # include runtime output jars
    elif target[JavaInfo].runtime_output_jars:
        jars = target[JavaInfo].runtime_output_jars
        source_jars = target[JavaInfo].source_jars
        dependencies = [struct(
            type = "jar",
            class_jar = jar,
            source_jar = source_jar,
        ) for (jar, source_jar) in zip(
            jars, source_jars + [None] * (len(jars) - len(source_jars))
        )]
    else:
        fail("Unsure how to package dependency for target: %s" % target)

    return JarInfo(
        name = maven_coordinates,
        deps = depset(dependencies, transitive = [
            # Filter transitive JARs from dependency that has maven coordinates
            # because those dependencies will already include the JARs as part
            # of their classpath
            depset([dep for dep in target[JarInfo].deps.to_list() if dep.type == 'pom'])
                if target[JarInfo].name else target[JarInfo].deps for target in deps_all
        ]),
    )

aggregate_dependency_info = aspect(
    attr_aspects = [
        "jars",
        "deps",
        "exports",
        "runtime_deps",
    ],
    doc = "Collects the Maven coordinates of the given java_library, its direct dependencies, and its transitive dependencies",
    implementation = _aggregate_dependency_info_impl,
    provides = [JarInfo],
)

assemble_maven = rule(
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [
                aggregate_dependency_info,
            ],
            doc = "Java target for subsequent deployment",
        ),
        "version_file": attr.label(
            allow_single_file = True,
            doc = """
            File containing version string.
            Alternatively, pass --define version=VERSION to Bazel invocation.
            Not specifying version at all defaults to '0.0.0'
            """,
        ),
        "workspace_refs": attr.label(
            allow_single_file = True,
            doc = "JSON file describing dependencies to other Bazel workspaces",
        ),
        "version_overrides": attr.string_dict(
            default = {},
            doc = "Dictionary of maven artifact : version to pin artifact versions to",
        ),
        "project_name": attr.string(
            default = "PROJECT_NAME",
            doc = "Project name to fill into pom.xml",
        ),
        "project_description": attr.string(
            default = "PROJECT_DESCRIPTION",
            doc = "Project description to fill into pom.xml",
        ),
        "project_url": attr.string(
            default = "PROJECT_URL",
            doc = "Project URL to fill into pom.xml",
        ),
        "license": attr.string(
            values = ["apache", "mit"],
            default = "apache",
            doc = "Project license to fill into pom.xml",
        ),
        "scm_url": attr.string(
            default = "PROJECT_URL",
            doc = "Project source control URL to fill into pom.xml",
        ),
        "developers": attr.string_list_dict(
            default = {},
            doc = "Project developers to fill into pom.xml",
        ),
        "platform_overrides": attr.label_keyed_string_dict(
            default = {},
            aspects = [
                aggregate_dependency_info,
            ],
            doc = """
Per-platform overrides for a dependency. Expects a dict of bazel labels to a JSON-encoded list of maven coordinates.
Ex.:
assemble_maven(
    ...
    platform_overrides = {
        ":bazel-dependency": json.encode([
            "org.company:dependency-windows-x86_64:{pom_version}",
            "org.company:dependency-linux-aarch64:{pom_version}",
            "org.company:dependency-linux-x86_64:{pom_version}",
            "org.company:dependency-macosx-aarch64:{pom_version}",
            "org.company:dependency-macosx-x86_64:{pom_version}",
        ])
    }
)
            """,
        ),
        "_pom_generator": attr.label(
            default = "@vaticle_bazel_distribution//maven:pom-generator",
            executable = True,
            cfg = "host",
        ),
        "_jar_assembler": attr.label(
            default = "@vaticle_bazel_distribution//maven:jar-assembler",
            executable = True,
            cfg = "host",
        ),
    },
    implementation = _assemble_maven_impl,
    doc = "Assemble Java package for subsequent deployment to Maven repo",
)


###############################
####    MAVEN DEPLOYMENT   ####
###############################


MavenDeploymentInfo = provider(
    fields = {
        'jar': 'JAR file to deploy',
        'srcjar': 'JAR file with sources',
        'pom': 'Accompanying pom.xml file'
    }
)

def _deploy_maven_impl(ctx):
    deploy_maven_script = ctx.actions.declare_file(ctx.attr.deploy_script_name)

    lib_jar_link = "lib.jar"
    src_jar_link = "lib.srcjar"
    pom_xml_link = ctx.attr.target[MavenDeploymentInfo].pom.basename

    release_repo = ctx.attr.release
    if _DEPLOY_MAVEN_RELEASE_REPO_KEY in ctx.var:
        release_repo = ctx.var[_DEPLOY_MAVEN_RELEASE_REPO_KEY]

    ctx.actions.expand_template(
        template = ctx.file._deploy_script_template,
        output = deploy_maven_script,
        substitutions = {
            "$JAR_PATH": lib_jar_link,
            "$SRCJAR_PATH": src_jar_link,
            "$POM_PATH": pom_xml_link,
            "{snapshot}": ctx.attr.snapshot,
            "{release}": release_repo,
        }
    )

    files = [
        ctx.attr.target[MavenDeploymentInfo].jar,
        ctx.attr.target[MavenDeploymentInfo].pom,
    ]
    symlinks = {
        lib_jar_link: ctx.attr.target[MavenDeploymentInfo].jar,
        pom_xml_link: ctx.attr.target[MavenDeploymentInfo].pom,
    }
    if ctx.attr.target[MavenDeploymentInfo].srcjar:
        files.append(ctx.attr.target[MavenDeploymentInfo].srcjar)
        symlinks[src_jar_link] = ctx.attr.target[MavenDeploymentInfo].srcjar

    return DefaultInfo(
        executable = deploy_maven_script,
        runfiles = ctx.runfiles(files=files, symlinks = symlinks)
    )

_deploy_maven = rule(
    attrs = {
        "target": attr.label(
            mandatory = True,
            providers = [MavenDeploymentInfo],
            doc = "assemble_maven target to deploy"
        ),
        "snapshot" : attr.string(
            mandatory = True,
            doc = 'Snapshot repository to release maven artifact to',
        ),
        "release" : attr.string(
            mandatory = True,
            doc = 'Release repository to release maven artifact to'
        ),
        "_deploy_script_template": attr.label(
            allow_single_file = True,
            default = "//maven/templates:deploy.py",
        ),
        "deploy_script_name": attr.string(
            mandatory = True,
            doc = 'Name of instantiated deployment script'
        )
    },
    executable = True,
    implementation = _deploy_maven_impl,
    doc = """
    Deploy `assemble_maven` target into Maven repo.

    Select deployment to `snapshot` or `release` repository with `bazel run //:some-deploy-maven -- [snapshot|release]
    """
)

def deploy_maven(name, target, snapshot, release, **kwargs):
    deploy_script_target_name = name + "__deploy"
    deploy_script_name = deploy_script_target_name + "-deploy.py"

    _deploy_maven(
        name = deploy_script_target_name,
        deploy_script_name = deploy_script_name,
        target = target,
        snapshot = snapshot,
        release = release,
        **kwargs
    )

    native.py_binary(
        name = name,
        srcs = [deploy_script_target_name],
        main = deploy_script_name
    )
