process say_hello{
  container 'python:3.10'
  input:
    val name
  output:
    path "hello.txt"
  script:
    """
    example_hello.py $name > hello.txt
    """
}

workflow example {
  names = Channel.from(["Alex", "World"])
  say_hello(names).subscribe{
    log.info(it.getText())
  }
}
