#include <stdio.h>
#include <stdint.h>

// Declarações das funções da sua API em assembly
void setup_brk();
void dismiss_brk();
void *memory_alloc(unsigned long bytes);
int memory_free(void *ptr);

void print_block(const char *msg, void *p) {
    if (!p) printf("%s NULL\n", msg);
    else    printf("%s %p\n", msg, p);
}

int main() {
    printf("==== INÍCIO DOS TESTES ====\n");
    setup_brk();

    // ============================================================
    // 1) Não tem bloco livre → alocar no final da heap (sobe o brk)
    // ============================================================
    printf("\n[CASO 1] Alocação sem blocos livres (heap nova):\n");
    void *a = memory_alloc(20);
    print_block("Bloco A:", a);

    void *b = memory_alloc(30);
    print_block("Bloco B:", b);

    // ============================================================
    // 2) Free em bloco e alocação NO MESMO bloco SEM split
    //    (bloco exato ou menor do que y+10)
    // ============================================================
    printf("\n[CASO 2] Free seguido de alocação no bloco, SEM split:\n");

    memory_free(a);               // libera bloco A (tamanho 20)
    printf("A liberado.\n");

    // requisita algo que NÃO permita split (ex: 15 → 15+9+1 = 25 > 20)
    void *c = memory_alloc(15);
    print_block("Bloco C (reuso de A sem split):", c);

    // ============================================================
    // 3) Free em bloco e alocação COM split
    // ============================================================
    printf("\n[CASO 3] Free seguido de alocação COM split:\n");

    memory_free(b);               // bloco B tinha 30 bytes
    printf("B liberado.\n");

    // agora pede algo pequeno o suficiente para gerar split (ex: 10 → 10+10 = 20 < 30)
    void *d = memory_alloc(10);
    print_block("Bloco D (usou parte de B com split):", d);

    dismiss_brk();
    printf("\n==== FIM ====\n");

    return 0;
}

