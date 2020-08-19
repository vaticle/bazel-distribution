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

def _deploy_github_impl(ctx):
    _deploy_script = ctx.actions.declare_file("{}_deploy.py".format(ctx.attr.name))

    if not ctx.attr.version_file:
        version_file = ctx.actions.declare_file(ctx.attr.name + "__do_not_reference.version")
        version = ctx.var.get('version', '0.0.0')

        ctx.actions.run_shell(
            inputs = [],
            outputs = [version_file],
            command = "echo {} > {}".format(version, version_file.path)
        )
    else:
        version_file = ctx.file.version_file

    ctx.actions.expand_template(
        template = ctx.file._deploy_script,
        output = _deploy_script,
        substitutions = {
            "{archive}": ctx.file.archive.short_path if (ctx.file.archive!=None) else "",
            "{has_release_description}": str(int(bool(ctx.file.release_description))),
            "{ghr_osx_binary}": ctx.files._ghr[0].path,
            "{ghr_linux_binary}": ctx.files._ghr[1].path,
            "{release_title}": ctx.attr.title or "",
            "{title_append_version}": str(int(bool(ctx.attr.title_append_version))),
            "{repo_github_organisation}" : ctx.attr.repo_github_organisation,
            "{repo_github_repository}" : ctx.attr.repo_github_repository,
        }
    )
    files = [
        version_file,
    ] + ctx.files._ghr

    if ctx.file.archive!=None:
        files.append(ctx.file.archive)

    symlinks = {
        'VERSION': version_file
    }

    if ctx.file.release_description:
        files.append(ctx.file.release_description)
        symlinks["release_description.txt"] = ctx.file.release_description

    return DefaultInfo(
        executable = _deploy_script,
        runfiles = ctx.runfiles(
            files = files,
            symlinks = symlinks
        ),
    )


deploy_github = rule(
    attrs = {
        "archive": attr.label(
            mandatory = False,
            allow_single_file = [".zip"],
            doc = "`assemble_versioned` label to be deployed.",
        ),
        "title": attr.string(
            mandatory = False,
            doc = "Title of GitHub release"
        ),
        "title_append_version": attr.bool(
            default = False,
            doc = "Append version to GitHub release title"
        ),
        "release_description": attr.label(
            allow_single_file = True,
            doc = "Description of GitHub release"
        ),
        "repo_github_organisation" : attr.string(
            mandatory = True,
            doc = "Github organisation to deploy to",
        ),
        "repo_github_repository" : attr.string(
            mandatory = True,
            doc = "Github repository to deploy to within repo_github_organisation",
        ),
        "version_file": attr.label(
            allow_single_file = True,
            doc = """
            File containing version string.
            Alternatively, pass --define version=VERSION to Bazel invocation.
            Not specifying version at all defaults to '0.0.0'
            """
        ),
        "_deploy_script": attr.label(
            allow_single_file = True,
            default = "//distribution/github/templates:deploy.py",
        ),
        "_ghr": attr.label_list(
            allow_files = True,
            default = ["@ghr_osx_zip//:ghr", "@ghr_linux_tar//:ghr"]
        ),
    },
    implementation = _deploy_github_impl,
    executable = True,
    doc = "Deploy `assemble_versioned` target to GitHub Releases"
)
