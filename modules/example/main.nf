process say_hello{
  container params.python_container
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
  names_ch = Channel.fromList(["Alex", "World"])
  say_hello(names_ch).subscribe{
    log.info(it.getText())
  }
}
