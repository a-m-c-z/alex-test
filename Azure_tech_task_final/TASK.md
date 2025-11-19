# Scenario

At EDF we have been informed that SQL server has a critical vulnerability! To remediate this and track our exposure we need an ad-hoc report that outputs all the hosts which have SQL server installed. Stakeholders have also requested that they want to be able to track the VMs with SQL server installed so that they can be confident updates are being installed.

# Task

1. We have an output in our pre-processing blobstore which is a complete export of all of our virtual machine instances. Please provide a script which will filter this csv and export the contents to a post processing blob-storage as an excel or csv document.

2. In addition to the script we also need to provide appropriate access for the various roles in the development, these will be assumed by organisation SSO so we only need the role to be defined. We have four individuals who are examples:

Jess Admin: This person needs control over the pre processing and post processing bucket to be able to completely clear the system down

Jeff Developer: This person will be involved in maintaining the solution, they need to be able to trigger the automation and remove the outputs when necessary

Bob Reader: They need to be able to extract and read the report, they pass this to other stakeholders

Raj Client: They are a stakeholder in the project that consumes the end report

3. We are concerned about the distribution of this data, so a password has been supplied in the pre processing bucket under “password.txt” however anyone with read access can access this even if they shouldn’t be able to. This should be rotated regularly and readable only by those with access to the system.

4. Please consider how this could be improved. You are welcome to use any tools that you would like, however at EDF we make use of tflint, checkov and the python black formatter for quality reasons. We encourage the use of AI tooling, but where you have used it to generate code we ask that you document this with a comment.

We have provided a skeleton of a terraform module, please provide a working deployment of the described system. Please include relevant outputs that you feel downstream users or infrastructure may need.

We expect you to spend approximately 3 hours on this task, this may not give you enough time to complete all aspects of the system we are happy for you to take longer if you would like to. Please also include your estimate of time spent on the task and write ups on features you were not able to complete. Please include a readme explaining how to use your solution.

Please feel free to create a short 5 minute presentation that outlines your key decisions on your submitted solution. If there are components you felt could not be implemented in the task then we would love to hear about them in this presentation.