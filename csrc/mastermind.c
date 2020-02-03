#include <ctype.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* Bit Routines */
#define BITFIELD_DECL(name, sz) unsigned char name[(((sz)-1)/8)+1]

#define SET_BIT(bf, n) \
    do { (bf)[(n)/8] |= (1 << ((n)%8)); } while(0)

#define CLR_BIT(bf, n) \
    do { (bf)[(n)/8] &= ~(1 << ((n)%8)); } while(0)

#define TOG_BIT(bf, n) \
    do { (bf)[(n)/8] ^= (1 << ((n)%8)); } while(0)

#define COND_BIT(bf, n, v) \
    do { \
        (bf)[(n)/8] &= ~(1 << ((n)%8)); \
        (bf)[(n)/8] |= (((v)!=0) << ((n)%8)); \
    } while(0)

#define GET_BIT(bf, n) ((bf)[(n)/8] & (1 << ((n)%8)))

/* Char to Code */
#define upper_to_idx(c) ((c)-'A')
#define lower_to_idx(c) ((c)-'a')
#define idx_to_upper(c) ((c)+'A')

/* Consts and Typedefs */
#define BOARD_SIZE  4
#define NUM_CODES   6
#define MAX_GUESS   8

typedef enum {
    GUESS_NONE=0,
    GUESS_MOVE,
    GUESS_WRONG,
    GUESS_OK,
} guess_t;

/* Globals */
static int correct_code[BOARD_SIZE];
static int current_code[BOARD_SIZE];

static BITFIELD_DECL(used_codes, BOARD_SIZE);
static guess_t current_result[BOARD_SIZE];

static char input_buf[256];

static void init_board(void) {
    int i;

    for(i = 0; i < BOARD_SIZE; ++i) {
        correct_code[i] = rand() % NUM_CODES;
    }
}

static void test_guess(void) {
    int i, j;

    memset(used_codes, 0, sizeof(used_codes));
    memset(current_result, GUESS_NONE, sizeof(current_result));

    // Check for perfect match
    for(i = 0; i < BOARD_SIZE; ++i) {
        if(correct_code[i] == current_code[i]) {
            SET_BIT(used_codes, i);
            current_result[i] = GUESS_OK;
            continue;
        }
    }

    for(i = 0; i < BOARD_SIZE; ++i) {
        if(current_result[i] != GUESS_NONE)
            continue;

        ++current_result[i];
        for(j = 0; j < BOARD_SIZE; ++j) {
            if(correct_code[j] == current_code[i]
            && !GET_BIT(used_codes, j)) {
                
                SET_BIT(used_codes, j);
                goto cont;
            }
        }

        ++current_result[i];
cont:;
    }

}

static int get_guess(void) {
    int i;
    size_t len;

    fgets(input_buf, sizeof(input_buf), stdin);
    
    len = strlen(input_buf);
    if(input_buf[len-1] == '\n') {
        input_buf[len-1] = '\0';
        --len;
    }

    if(len != BOARD_SIZE)
        return 0;

    for(i = 0; i < BOARD_SIZE; ++i) {
        if(isupper(input_buf[i])) {
            current_code[i] = upper_to_idx(input_buf[i]);
        } else if(islower(input_buf[i])) {
            current_code[i] = lower_to_idx(input_buf[i]);
        } else {
            return 0;
        }

        if(current_code[i] >= NUM_CODES) {
            return 0;
        }
    }

    return 1;
}

static void print_code(int *code) {
    int i;

    for(i = 0; i < BOARD_SIZE; ++i) {
        putchar(idx_to_upper(code[i]));
    }
}

static int print_result(void) {
    int num_ok = 0;
    int i;

    for(i = 0; i < BOARD_SIZE; ++i) {
        switch(current_result[i]) {
        case GUESS_OK:      putchar('O'); ++num_ok; break;
        case GUESS_MOVE:    putchar('X'); break;
        case GUESS_WRONG:   putchar(' '); break;
        }
    }

    putchar('\n');
    return num_ok;
}

static void do_game(void) {
    int num_ok;
    int turns_done = 0;

    printf("Size: %d, Codes: %d, Guesses: %d\n", BOARD_SIZE, NUM_CODES, MAX_GUESS);
    while(turns_done < MAX_GUESS) {
        printf("Guess %d:\n", turns_done + 1);
        while(!get_guess()) {
            printf("Invalid input\n");
        }

        test_guess();
        num_ok = print_result();

        if(num_ok == BOARD_SIZE) {
            printf("You won!");
            break;
        }

        ++turns_done;
    }

    if(turns_done == MAX_GUESS) {
        printf("Game over. Correct code: ");
        print_code(correct_code);
        putchar('\n');
    }
}

int main(void) {
    // Inits
    setvbuf (stdout, NULL, _IONBF, 0);
    srand((unsigned) time(NULL));

    init_board();
    do_game();

    return 0;
}
