process say_hello{
  container 'python:3.11'
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
  names_ch = Channel.from(["Alex", "World"])
  say_hello(names_ch).subscribe{
    log.info(it.getText())
  }
}
