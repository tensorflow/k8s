{
  // TODO(https://github.com/ksonnet/ksonnet/issues/222): Taking namespace as an argument is a work around for the fact that ksonnet
  // doesn't support automatically piping in the namespace from the environment to prototypes.

  // convert a list of two items into a map representing an environment variable
  // TODO(jlewi): Should we move this into kubeflow/core/util.libsonnet
  listToMap:: function(v)
    {
      name: v[0],
      value: v[1],
    },

  // Function to turn comma separated list of prow environment variables into a dictionary.
  parseEnv:: function(v)
    local pieces = std.split(v, ",");
    if v != "" && std.length(pieces) > 0 then
      std.map(
        function(i) $.listToMap(std.split(i, "=")),
        std.split(v, ",")
      )
    else [],

  parts(namespace, name):: {
    // Workflow to run the e2e test.
    e2e(prow_env, bucket):
      // mountPath is the directory where the volume to store the test data
      // should be mounted.
      local mountPath = "/mnt/" + "test-data-volume";
      // testDir is the root directory for all data for a particular test run.
      local testDir = mountPath + "/" + name;
      // outputDir is the directory to sync to GCS to contain the output for this job.
      local outputDir = testDir + "/output";
      local artifactsDir = outputDir + "/artifacts";
      local goDir = testDir + "/go";
      local srcDir = testDir + "/src";
      local image = "gcr.io/mlkube-testing/test-worker";
      // The name of the NFS volume claim to use for test files.
      // local nfsVolumeClaim = "kubeflow-testing";
      local nfsVolumeClaim = "nfs-external";
      // The name to use for the volume to use to contain test data.
      local dataVolume = "kubeflow-test-volume";
      local versionTag = name;
      // The directory within the kubeflow_testing submodule containing 
      // py scripts to use.
      local kubeflowPy = srcDir + "/kubeflow_testing/py";

      local project = "mlkube-testing";
      // GKE cluster to use
      local cluster = name;
      local zone = "us-east1-d";
      local chart = srcDir + "/bin/tf-job-operator-chart-0.2.1-" + versionTag + ".tgz";
      {
        // Build an Argo template to execute a particular command.
        // step_name: Name for the template
        // command: List to pass as the container command.
        buildTemplate(step_name, command):: {
          name: step_name,
          container: {
            command: command,
            image: image,
            env: [
              {
                // Add the source directories to the python path.
                name: "PYTHONPATH",
                value: srcDir + ":" + kubeflowPy,
              },
              {
                // Set the GOPATH
                name: "GOPATH",
                value: goDir,
              },
              {
                name: "GOOGLE_APPLICATION_CREDENTIALS",
                value: "/secret/gcp-credentials/key.json",
              },
              {
                name: "GIT_TOKEN",
                valueFrom: {
                  secretKeyRef: {
                    name: "github-token",
                    key: "github_token",
                  },
                },
              },
            ] + prow_env,
            volumeMounts: [
              {
                name: dataVolume,
                mountPath: mountPath,
              },
              {
                name: "github-token",
                mountPath: "/secret/github-token",
              },
              {
                name: "gcp-credentials",
                mountPath: "/secret/gcp-credentials",
              },
            ],
          },
        },  // buildTemplate

        apiVersion: "argoproj.io/v1alpha1",
        kind: "Workflow",
        metadata: {
          name: name,
          namespace: namespace,
        },
        // TODO(jlewi): Use OnExit to run cleanup steps.
        spec: {
          entrypoint: "e2e",
          volumes: [
            {
              name: "github-token",
              secret: {
                secretName: "github-token",
              },
            },
            {
              name: "gcp-credentials",
              secret: {
                secretName: "kubeflow-testing-credentials",
              },
            },
            {
              name: dataVolume,
              persistentVolumeClaim: {
                claimName: nfsVolumeClaim,
              },
            },
          ],  // volumes
          templates: [
            {
              name: "e2e",
              steps: [
                [{
                  name: "checkout",
                  template: "checkout",
                }],
                [
                  {
                    name: "build",
                    template: "build",
                  },
                  {
                    name: "create-pr-symlink",
                    template: "create-pr-symlink",
                  },
                  {
                    name: "py-test",
                    template: "py-test",
                  },
                  {
                    name: "py-lint",
                    template: "py-lint",
                  },
                ],
                [ // Setup cluster needs to run after build because we depend on the chart
                  // created by the build statement.
                  {
                    name: "setup-cluster",
                    template: "setup-cluster",
                  },
                ],
                [
                  {
                    name: "run-tests",
                    template: "run-tests",
                  },
                  {
                    name: "run-gpu-tests",
                    template: "run-gpu-tests",
                  },
                ],
                [{
                  name: "copy-artifacts",
                  template: "copy-artifacts",
                }],
              ],
            },
            {
              name: "checkout",
              container: {
                command: [
                  "/usr/local/bin/checkout.sh",
                ],
                args: [
                  srcDir,
                ],
                env: prow_env,
                image: image,
                volumeMounts: [
                  {
                    name: dataVolume,
                    mountPath: mountPath,
                  },
                ],
              },
            },  // checkout
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("build", [
              "python",
              "-m",
              "py.release", 
              "build", 
              "--src_dir=" + srcDir,
              "--project=mlkube-testing",
              "--version_tag=" + versionTag,
            ]),  // build
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("py-test", [
              "python",
              "-m",
              "py.py_checks", 
              "test", 
              "--src_dir=" + srcDir,
              "--project=mlkube-testing",
              "--junit_path=" +  artifactsDir + "/junit_pycheckstest.xml",
            ]),  // py test
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("py-lint", [
              "python",
              "-m",
              "py.py_checks", 
              "lint", 
              "--src_dir=" + srcDir,
              "--project=mlkube-testing",
              "--junit_path=" +  artifactsDir + "/junit_pycheckslint.xml",
            ]),  // py lint
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("setup-cluster", [
              "python",
              "-m",
              "py.deploy", 
              "setup", 
              "--cluster=" + cluster,
              "--zone=" + zone,
              "--project=" + project,
              "--chart=" + chart,
              "--accelerator=nvidia-tesla-k80=1",
              "--junit_path=" +  artifactsDir + "/junit_setupcluster.xml",
            ]),  // setup cluster
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("run-tests", [
              "python",
              "-m",
              "py.deploy", 
              "test", 
              "--cluster=" + cluster,
              "--zone=" + zone,
              "--project=" + project,              
              "--junit_path=" +  artifactsDir + "/junit_e2e.xml",
            ]),  // run tests
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("run-gpu-tests", [
              "python",
              "-m",
              "py.test_runner", 
              "test", 
              "--spec=" + srcDir + "examples/tf_job_gpu.yaml",
              "--cluster=" + cluster,
              "--zone=" + zone,
              "--project=" + project,              
              "--junit_path=" +  artifactsDir + "/junit_gpu-tests.xml",
              // tf_job_gpu.yaml has the image tag hardcoded so the tag doesn't matter.
              // TODO(jlewi): The example should be a template and we should rebuild and
              // and use the newly built sample container.
              "--image_tag=notag",
            ]),  // run gpu_tests
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("create-pr-symlink", [
              "python",
              "-m",
              "kubeflow.testing.prow_artifacts",
              "--artifacts_dir=" + outputDir,
              "create_pr_symlink",
              "--bucket=" + bucket,
            ]),  // create-pr-symlink
            $.parts(namespace, name).e2e(prow_env, bucket).buildTemplate("copy-artifacts", [
              "python",
              "-m",
              "kubeflow.testing.prow_artifacts",
              "--artifacts_dir=" + outputDir,
              "copy_artifacts",
              "--bucket=" + bucket,
            ]),  // copy-artifacts
          ],  // templates
        },
      },  // e2e
  },  // parts
}