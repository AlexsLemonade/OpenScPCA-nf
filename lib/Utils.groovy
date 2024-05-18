
import nextflow.Nextflow

/**
 * Utility functions for OpenScPCA-nf
 */
class Utils {
  static def getReleasePath(bucket, release = "current"){

    def bucket_path = Nextflow.file(bucket, type: 'dir')
    if (!bucket_path.exists()) {
      throw new IllegalArgumentException("Bucket '${bucket}' does not exist")
    }
    if (!release) {
      throw new IllegalArgumentException("release can not be blank")
    }
    if (release == "current") {
      def today = new Date().format('yyyy-MM-dd')
      release = bucket_path.list().findAll{it <= today}.max()
    }
    def release_path = bucket_path / release
    println("Using release '${release}' from '${bucket}'")
    if (!release_path.exists()) {
      throw new IllegalArgumentException("Release '${release}' does not exist in '${bucket}'")
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

  static def getProjectFiles(Map args, project_dir){
    def format = args.format ?: "sce"
    def process_level = args.process_level ?: "processed"

    project_dir = Nextflow.file(project_dir, type: 'dir')
    process_level = process_level.toLowerCase()
    if (!(process_level in ["raw", "filtered", "processed"])){
      throw new IllegalArgumentException("Unknown process_level '${process_level}'")
      }
    def files = []
    switch (format.toLowerCase()){
      case ["anndata", "h5ad"]:
        // find all h5ad files in the project directory (** searches all subdirectories)
        files = Nextflow.files(project_dir / "**_${process_level}_*.h5ad")
        break
      case ["sce", "rds"]:
        def extension="rds"
        files = Nextflow.files(project_dir / "**_${process_level}.rds")
        break
      default:
        throw new IllegalArgumentException("Unknown format '${format}'")
        break
    }
    files = files.findAll{it.size() > 0}
    return files
 }
}
