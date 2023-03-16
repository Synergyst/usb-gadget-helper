#include <iostream>
#include <string>
#include <sstream>
unsigned long bin_to_int(std::string m_str) {
  return stoul(m_str.substr(2), nullptr, 2);
}
std::string int_to_bin(int num) {
  std::stringstream ss;
  ss << "11";
  for (int i = 0; i < num; i++) {
    ss << "1";
  }
  return ss.str();
}
uint num_channels(uint chanmask) {
  uint num = 0;
  while (chanmask) {
    num += (chanmask & 1);
    chanmask >>= 1;
  }
  return num;
}
int main(int argc, char* argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Error: Not enough arguments\nUsage: %s <desired channels>\n", argv[0]);
    return 1;
  } else {
    if (atoi(argv[1]) < 1) {
      fprintf(stderr, "Error: desired channels can NOT be less than 1\nUsage: %s <desired channels>\n", argv[0]);
      return 1;
    } else if (atoi(argv[1]) > 27) {
      fprintf(stderr, "Error: can NOT assign more than 27 channels\nUsage: %s <desired channels>\n", argv[0]);
    /*} else if (atoi(argv[1]) > 32) {
      fprintf(stderr, "Error: can NOT assign more than 32 channels\nUsage: %s <desired channels>\n", argv[0]);*/
      return 1;
    }
  }
  int desiredChannels = atoi(argv[1]);
  printf("Binary mask (as int): %u\nBinary mask: %s\nChannels: %d\n", bin_to_int(int_to_bin(desiredChannels)), int_to_bin(desiredChannels).c_str(), num_channels(bin_to_int(int_to_bin(desiredChannels))));
  return 0;
}
