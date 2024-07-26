---
name: Create a workflow release
about: Use this to track creating a semantically-versioned release
title: "Create a release: vX.Y.Z"
labels: release
---

If issues must be resolved before creating a release, mark them as blockers in ZenHub.

**Pre-release checklist:**

- [ ] Add the upcoming release version to add to the title of this issue!
- [ ] All blocking issues have been resolved
- [ ] All Docker images use a versioned tag (i.e. `:latest` or `:edge` is not used)
- [ ] The default data release in [`nextflow.config`](https://github.com/AlexsLemonade/OpenScPCA-nf/blob/main/nextflow.config) is up-to-date. (See [OpenScPCA-analysis announcements](https://github.com/AlexsLemonade/OpenScPCA-analysis/discussions/categories/announcements?discussions_q=category:Announcements) for the latest data release version, or run `./download-data.py --list-releases` from the `OpenScPCA-analysis` repository.)
- [ ] The full workflow has been run successfully
  - [ ] Trigger with [Run Workflow on AWS Batch](https://github.com/AlexsLemonade/OpenScPCA-nf/actions/workflows/run-batch.yml) GitHub Action using **Workflow run mode** "full" and **Workflow output mode** "staging"
  - [ ] Check output data in the staging buckets:
    - [ ] `s3://openscpca-nf-workflow-results-staging`
    - [ ] `s3://openscpca-test-data-release-staging`
    - [ ] `s3://openscpca-test-workflow-results-staging`
- [ ] Any mentions of the workflow version in the repository have been updated, including
  -  [ ] [`nextflow.config`](https://github.com/AlexsLemonade/OpenScPCA-nf/blob/main/nextflow.config) manifest
  -  [ ] [`CHANGELOG.md`](https://github.com/AlexsLemonade/OpenScPCA-nf/blob/main/CHANGELOG.md) (see more below)
- [ ] Write release notes and add them to [`CHANGELOG.md`](https://github.com/AlexsLemonade/OpenScPCA-nf/blob/main/CHANGELOG.md), which should include the following:
  - Which modules have been added or removed, if any?
  - Have there been any changes to the workflow configuration or launch instructions?
  - What has changed in the workflow documentation, if anything?
- [ ] [Create a release on GitHub](https://github.com/AlexsLemonade/OpenScPCA-nf/releases/new) with a new tag of the version number in vX.Y.Z format
  - [ ] Populate the description with the release notes added to the changelog. Note that you may find it helpful to use GitHub's automated release notes generation when updating the changelog.
