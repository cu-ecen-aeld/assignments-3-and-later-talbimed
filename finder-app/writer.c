#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>



int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <string> <file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    char *string = argv[2];
    char *file_path = argv[1];

    FILE *file = fopen(file_path, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Error opening file: %s", file_path);
        perror("Error opening file");
        exit(EXIT_FAILURE);
    }

    fprintf(file, "%s", string);
    fclose(file);

    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);
    syslog(LOG_DEBUG, "Writing \"%s\" to \"%s\"", string, file_path);
    closelog();

    return 0;
}
