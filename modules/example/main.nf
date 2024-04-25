def publish_base = Utils.getResultsPath(params.results_bucket, params.results_prefix, "example")
process say_hello{
  container 'python:3.11'
  publishDir publish_base, mode: 'copy'
  input:
    val name
  output:
    path outfile
  script:
    outfile = "hello-${name}.txt"
    """
    hello.py $name > $outfile
    """
}

workflow example {
  names = Channel.from(["Alex", "World"])
  say_hello(names).subscribe{
    log.info(it.getText())
  }
}
