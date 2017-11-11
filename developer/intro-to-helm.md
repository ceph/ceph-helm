I'm new to Helm!
===============
This guide assumes you are relatively familiar with the basic concepts of how Kubernetes (k8s) is configured.

In a nutshell, Helm is a tool that makes it easier to manage Kubernetes applications with lots of moving parts -- and lots of Kubernetes config files -- by creating all of the necessary k8s config files automagically and sending them to k8s.

Quick links
-----------
Helm project: https://github.com/kubernetes/helm <br>
Helm docs: https://docs.helm.sh/ <br>
Charts project: https://github.com/kubernetes/charts <br>

What is a chart?
----------------
Helm's readme will tell you that "Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources." First of all, I find the terminology "Kubernetes charts" to be a bit of a misnomer. They're really Helm charts. Kubernetes doesn't really care; it just wants its config (YAML) files.

This site is a good intro to what a chart actually is and should shed some light on Helm too: http://blog.kubernetes.io/2016/10/helm-charts-making-it-simple-to-package-and-deploy-apps-on-kubernetes.html

How do charts work?
-------------------
From a high level, Helm creates all of the Kubernetes config YAML files for you with the magic of templates. Helm abstracts the plethora of k8s config files behind a smaller, more manageable set of user inputs which give values for templates to take on. This is the `values.yaml` which is effectively the public API of a chart.
