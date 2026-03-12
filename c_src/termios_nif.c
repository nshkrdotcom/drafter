#include <erl_nif.h>
#include <termios.h>
#include <unistd.h>
#include <string.h>

static struct termios original_termios;
static int termios_saved = 0;

static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
    atom_ok = enif_make_atom(env, "ok");
    atom_error = enif_make_atom(env, "error");
    return 0;
}

static ERL_NIF_TERM disable_flow_control(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    struct termios raw;
    
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return atom_error;
    }
    
    if (!termios_saved) {
        memcpy(&original_termios, &raw, sizeof(struct termios));
        termios_saved = 1;
    }
    
    raw.c_iflag &= ~(IXON | IXOFF | IXANY);
    
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1) {
        return atom_error;
    }
    
    return atom_ok;
}

static ERL_NIF_TERM enable_flow_control(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    struct termios raw;
    
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return atom_error;
    }
    
    raw.c_iflag |= (IXON | IXOFF);
    
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1) {
        return atom_error;
    }
    
    return atom_ok;
}

static ERL_NIF_TERM enter_raw_mode(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    struct termios raw;
    
    if (tcgetattr(STDIN_FILENO, &raw) == -1) {
        return atom_error;
    }
    
    if (!termios_saved) {
        memcpy(&original_termios, &raw, sizeof(struct termios));
        termios_saved = 1;
    }
    
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON | IXOFF | IXANY);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag |= (CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1) {
        return atom_error;
    }
    
    return atom_ok;
}

static ERL_NIF_TERM exit_raw_mode(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    if (termios_saved) {
        if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &original_termios) == -1) {
            return atom_error;
        }
    }
    return atom_ok;
}

static ErlNifFunc nif_funcs[] = {
    {"disable_flow_control", 0, disable_flow_control},
    {"enable_flow_control", 0, enable_flow_control},
    {"enter_raw_mode", 0, enter_raw_mode},
    {"exit_raw_mode", 0, exit_raw_mode}
};

ERL_NIF_INIT(Elixir.Drafter.Terminal.TermiosNif, nif_funcs, load, NULL, NULL, NULL)
