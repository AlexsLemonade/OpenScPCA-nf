
import nextflow.Nextflow

/**
 * Utility functions for OpenScPCA-nf
 */
class Utils {
  static def getReleasePath(bucket, release = "current"){
    def bucket_path = Nextflow.file("s3://${bucket}")
    if (!bucket_path.exists()) {
      throw new IllegalArgumentException("Bucket ${bucket} does not exist")
    }
    if (!release) {
      throw new IllegalArgumentException("release can not be blank")
    }
    else if (release == "current") {
      def today = new Date().format('yyyy-MM-dd')
      release = bucket_path.list().findAll{it <= today}.max()
    }
    def release_path = bucket_path / release
    if (!release_path.exists()) {
      throw new IllegalArgumentException("Release ${release} does not exist in ${bucket}")
    }
    return release_path
  }

  static def getProjects(release_path){
    release_path = Nextflow.file(release_path, type: 'dir')
    def projects = release_path.list().findAll{it.startsWith("SCPCP")}
    return projects
  }

  static def getProjectPaths(release_path){
    release_path = Nextflow.file(release_path, type: 'dir')
    def projects = getProjects(release_path)
    return projects.collect{release_path / it}
  }
}
