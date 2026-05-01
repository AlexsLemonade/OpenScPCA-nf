process say_hello{
  container Utils.pullthroughContainer(params.python_container, params.pullthrough_registry)
  input:
    val name
  output:
    path "hello.txt"
  script:
    """
    hello.py $name > hello.txt
    """
}

workflow example {
  names_ch = channel.fromList(["Alex", "World"])
  say_hello(names_ch).subscribe{ it ->
    log.info(it.getText())
  }
}
