#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <x86intrin.h>  /* __rdtsc, _mm_clflush */
#include <pthread.h>

/* AGLE - Algoritmo Canônico com Física de Ponto Flutuante
 * Realimentação de erro para inserir incerteza na equação
 */

typedef struct {
    double r;           /* parâmetro de não-linearidade: r > 0 (ex: 3.9999) */
    double alpha;       /* expoente de singularidade: α ≥ 0 (ex: 1.0) */
    double lambda;      /* realimentação do erro: λ > 0 (ex: 1.0) */
    double x;           /* estado caótico em [0,1) */
    double epsilon_acc; /* acumulador de erro para amplificação */
} AGLE;

/* Pool compartilhado para conflito de cache inter-core */
volatile uint64_t shared_entropy_pool __attribute__((aligned(64))) = 0;

static void *entropy_miner_core(void *arg) {
    (void)arg;
    while (1) {
        __sync_fetch_and_add(&shared_entropy_pool, 1); /* força bouncing de cache */
    }
    return NULL;
}

/* Inicializa o AGLE */
void agle_init(AGLE *gen, double r, double alpha, double lambda, double x0) {
    gen->r = r;
    gen->alpha = alpha;
    gen->lambda = lambda;
    gen->x = x0;
    gen->epsilon_acc = 0.0;
}

/* Gera um uint32 usando física de ponto flutuante com acumulação de erro */
uint32_t agle_next(AGLE *gen) {
    uint32_t result = 0;
    static int cache_dummy[1024]; /* alvo de cache para sonda L1 */
    
    /* 4 iterações internas para amplificar caos */
    for (int iter = 0; iter < 4; iter++) {
        /* Sonda inter-core: latência de L3/barramento */
        uint64_t t0_bus = __rdtsc();
        uint64_t val_bus = shared_entropy_pool;
        (void)val_bus;
        uint64_t t1_bus = __rdtsc();
        double physical_jitter = (double)((t1_bus - t0_bus) & 0xFFFF) / 65535.0;

        /* Sonda L1: mede latência e injeta jitter físico */
        uint64_t t0 = __rdtsc();
        int val = cache_dummy[iter % 1024];
        (void)val;
        uint64_t t1 = __rdtsc();
        double jitter = (double)((t1 - t0) & 0xFF) / 256.0;
        _mm_clflush(&cache_dummy[iter % 1024]);

        /* 1. Cálculo em precisão real (dupla) com epsilon acumulado */
        double f_real = gen->r * gen->x * (1.0 - gen->x) * pow(gen->x, -gen->alpha);
        f_real += jitter * 1e-7;          /* jitter L1 */
        f_real += physical_jitter * 1e-5; /* jitter inter-core */
        
        /* 2-3. Quantização IEEE-754 FÍSICA (double → float → double) */
        volatile float f32 = (float) f_real;  // perde 29 bits (REAL!)
        double f_quant = (double) f32;        // quantizado
        
        /* Erro físico de arredondamento (IRREVERSÍVEL!) */
        double epsilon = f_real - f_quant;    // erro IRREVERSÍVEL
        
        /* 4. Acumula erro para amplificação (retroalimentação no sistema) */
        gen->epsilon_acc = (gen->epsilon_acc + epsilon) - floor(gen->epsilon_acc + epsilon);
        
        /* 5. Mapa α-Gauss-Logístico com injeção de erro acumulado */
        double y = f_quant - floor(f_quant);
        
        /* 6. Realimentação dupla com combinação não-linear */
        gen->x = y + gen->lambda * epsilon + (gen->lambda * 0.3) * gen->epsilon_acc;
        gen->x = gen->x - floor(gen->x);
        
        /* 7. Extração de bits de cada iteração */
        uint64_t raw;
        memcpy(&raw, &gen->x, sizeof(uint64_t));
        uint32_t mantissa = (uint32_t)((raw >> 12) & 0xFFFFFFFFUL);
        
        /* Pega bits de epsilon */
        uint64_t eps_raw;
        memcpy(&eps_raw, &epsilon, sizeof(uint64_t));
        uint32_t eps_bits = (uint32_t)(eps_raw & 0xFFFFFFFFUL);
        
        /* Combina iterações com XOR */
        result ^= (mantissa ^ eps_bits);
    }
    
    return result;
}

int main(void) {
    /* Parâmetros do AGLE */
    double r = 3.9999;    /* regime fortemente caótico */
    double alpha = 1.0;   /* singularidade típica */
    double lambda = 3.0;  /* realimentação amplificada para inserir mais erro */
    double x0 = 0.123456789; /* estado inicial (reprodutível) */
    
    /* Sobe minerador de latência em outro núcleo */
    pthread_t miner_thread;
    if (pthread_create(&miner_thread, NULL, entropy_miner_core, NULL) == 0) {
        pthread_detach(miner_thread);
    }

    AGLE gen;
    agle_init(&gen, r, alpha, lambda, x0);
    
    /* Gera e emite números de 32 bits para dieharder */
    uint32_t buffer[512];
    
    while (1) {
        for (int i = 0; i < 512; i++) {
            buffer[i] = agle_next(&gen);
        }
        /* Escreve 512 * 4 = 2048 bytes em formato binário */
        fwrite(buffer, sizeof(uint32_t), 512, stdout);
        fflush(stdout);
    }
    
    return 0;
}
