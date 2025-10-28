resource "local_file" "jsj_abc" {
  content  = "abc!"
  filename = "${path.module}/jsj_abc.txt"
}
