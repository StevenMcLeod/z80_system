#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "minifb.h"

#define FIFO_NAME "fifo.in"

#define WIND_TITLE "Screenbuffer"
#define WIND_H 224
#define WIND_W 256

#define FRAME_RATE 60
#define FRAME_NS (1000000000L / FRAME_RATE)

#define exit_error(msg) do { fprintf(stderr, "%s\n", msg); exit(EXIT_FAILURE); } while(0)
#define exit_perror(msg) do { fprintf(stderr, "%s: %s\n", msg, strerror(errno)); exit(EXIT_FAILURE); } while(0)
#define exit_errorf(msg, ...) do { fprintf(stderr, msg, __VA_ARGS__); exit(EXIT_FAILURE); } while(0)

typedef uint32_t pix32;

// Globals
int fifo_d = -1;
struct Window *w = NULL;
pix32 *pixbuf = NULL;

static void del_fifo(void) {
    if(fifo_d != -1) {
        close(fifo_d);
    }

    unlink(FIFO_NAME);
}

static void handle_signal(int sig) {
    fprintf(stderr, "Found signal %d\n", sig);
    del_fifo();
    exit(EXIT_FAILURE);
}

static void handle_timer(int sigval) {
    int res;

    res = mfb_update(w, pixbuf);
    if(res != 0)
        exit_errorf("Received %d from MiniFB\n", res);
}

static void init_signals(void) {
    // Attach signal handlers
    signal(SIGHUP, &handle_signal);
    signal(SIGQUIT, &handle_signal);
    signal(SIGINT, &handle_signal);
    signal(SIGALRM, &handle_timer);
}

static void init_frame_timer(void) {
    timer_t timer;
    struct itimerspec ts;
    int res;

    res = timer_create(CLOCK_MONOTONIC, NULL, &timer);
    if(res != 0)
        exit_perror("Could not create timer");

    ts.it_value.tv_sec = 0;
    ts.it_value.tv_nsec = FRAME_NS;
    ts.it_interval.tv_sec = 0;
    ts.it_interval.tv_nsec = FRAME_NS;
    res = timer_settime(timer, 0, &ts, NULL);
    if(res != 0)
        exit_perror("Could not arm timer");
}

int main(void) {
    ssize_t rc;
    uint8_t nextbyte;
    size_t pixcntr = 0;
    size_t framecntr = 0;

    init_signals();
    
    // Create Pipe
    if(mkfifo(FIFO_NAME, S_IRUSR | S_IWUSR) != 0) {
        exit_perror("Could not create fifo");
    }

    atexit(&del_fifo);

    // Allocate Buffer
    pixbuf = malloc(WIND_H * WIND_W * sizeof(pix32));
    if(!pixbuf)
        exit_error("Could not allocate pixbuf");

    memset(pixbuf, 0x00, WIND_H * WIND_W * sizeof(pix32));

    // Open window
    w = mfb_open(WIND_TITLE, WIND_W, WIND_H);
    if(!w) {
        free(pixbuf);
        exit_error("Could not open window");
    }

    // Set up frame timer
    init_frame_timer();

    mfb_update(w, pixbuf);
    
    // Open pipe
    fifo_d = open(FIFO_NAME, O_RDONLY);
    if(fifo_d == -1) {
        exit_perror("Could not open fifo");
    }

    rc = read(fifo_d, &nextbyte, 1);
    while(rc != 0) {
        uint8_t r, g, b;
        
        r = (nextbyte & 0b00000111) << 5;
        g = (nextbyte & 0b00111000) << 2;
        b = (nextbyte & 0b11000000) << 0;

        pixbuf[pixcntr] = MFB_RGB(r, g, b);
        pixcntr = (pixcntr + 1) % (WIND_W * WIND_H);

        if(pixcntr == 0) {
            printf("Frame: %u\n", framecntr);
            ++framecntr;
        }

        rc = read(fifo_d, &nextbyte, 1);
    }

    mfb_update(w, pixbuf);
    puts("Received EOF, close window to quit");
    while(mfb_update_events(w) >= 0);
    
    if(pixbuf)
        free(pixbuf);

    if(w)
        mfb_close(w);

    return 0;
}
