#define PROT_PRINT 1

#include "PROT.h"
#include "PROT.c"
int main(int argc, const char** argv) {
  int ret;
  const char* web = argv[1];
  const char* topic = argv[2];
  const char* mode = argv[3];
  const char* user = argv[4];
  const char* db = argv[5];
  if (strcmp(web,"-") == 0)
	web = NULL;
  if (strcmp(topic,"-") == 0)
	topic = NULL;
  if (strcmp(user,"-") == 0)
	user = NULL;
  PROT_setDBpath(db);
  if (PROT_accessible(web, topic, mode, user))
	printf("permitted\n");
  else
	printf("denied\n");

  return 0;
}
