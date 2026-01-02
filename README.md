# AGLE – Alpha-Gauss-Logistic Entropy Generator

**Cryptographic Entropy Generator Based on Chaotic Dynamics with Floating-Point Error Feedback**

---

## 📋 Descrição

AGLE (Alpha-Gauss-Logistic Entropy Generator) é um gerador de entropia criptográfica baseado em dinâmica caótica com realimentação de erros de ponto flutuante. O sistema utiliza mapas caóticos combinados com processamento através de SHAKE256 (XOF - Extensible Output Function) para produzir sequências de alta qualidade entrópica.

Este projeto representa pesquisa original em geradores de números aleatórios criptográficos (CSPRNG) que exploram propriedades de irreversibilidade induzida por hardware em sistemas caóticos.

## 🔬 Características Técnicas

- **Fontes de Entropia**: `/dev/urandom` (Linux) + erros de ponto flutuante
- **Processamento**: SHAKE256 (SHA-3 family)
- **Conformidade**: Testes NIST SP 800-22
- **Segurança**: Design para uso criptográfico

## 📁 Estrutura do Projeto

```
├── agle_final.c          # Implementação principal AGLE
├── agle_rng.c            # Versão alternativa do RNG
├── agle_rng_final.c      # Versão final otimizada
├── agle_urandom.c        # Integração com /dev/urandom
├── test_shake256.c       # Testes unitários SHAKE256
├── LICENSE               # Licença RPL-1.0
└── README.md             # Este arquivo
```

## 🛠️ Compilação

### Requisitos

- GCC ou Clang
- OpenSSL 3.0+ (libssl-dev)
- Linux (para acesso a `/dev/urandom`)

### Compilar

```bash
# Versão principal
gcc -o agle agle_final.c -lssl -lcrypto -O3 -Wall

# Executar
./agle > output.bin
```

## 🧪 Testes

O projeto foi testado com a suíte NIST SP 800-22 Statistical Test Suite:

```bash
# Gerar dados para teste (1 milhão de bits)
./agle | head -c 125000 > test_data.bin

# Executar testes NIST
# (requer NIST STS instalado)
```

## 📊 Resultados

- ✅ Passa nos 15 testes estatísticos NIST SP 800-22
- ✅ Entropia Shannon > 7.99 bits/byte
- ✅ Sem padrões detectáveis por DieHarder
- ✅ Performance: > 10 MB/s

## 🔐 Licença

Este projeto está licenciado sob **AGLE RESEARCH & PATENT PROTECTION LICENSE (RPL-1.0)**.

**IMPORTANTE**: Este código é protegido por direitos autorais e patentes pendentes. 

### Uso Permitido
- Leitura e estudo acadêmico
- Citação em trabalhos científicos
- Revisão por pares

### Uso Proibido
- Uso comercial
- Implementação em produtos
- Criação de trabalhos derivados
- Treinamento de modelos de IA

Veja o arquivo [LICENSE](LICENSE) para detalhes completos.

## 👤 Autor

**André Gualberto**

- Email: angualberto@gmail.com
- GitHub: [@angualberto](https://github.com/angualberto)

## 📚 Citação

Se você utilizar este trabalho em pesquisa acadêmica, por favor cite:

```bibtex
@misc{gualberto2025agle,
  author = {Gualberto, André},
  title = {AGLE: Cryptographic Entropy Generator Based on Chaotic Dynamics with Floating-Point Error Feedback},
  year = {2025},
  publisher = {GitHub},
  url = {https://github.com/angualberto/Hardware-Induced-Irreversibility-in-Chaotic-Maps}
}
```

## ⚠️ Aviso Legal

Este software é fornecido "como está", sem garantias de qualquer tipo. O uso deste código em sistemas de produção requer análise de segurança independente.

## 🔬 Pesquisa Relacionada

Este projeto explora conceitos de:
- Teoria do Caos aplicada à criptografia
- Sistemas dinâmicos não-lineares
- Irreversibilidade computacional
- Geradores de números pseudo-aleatórios criptográficos (CSPRNG)

---

**Copyright © 2025 André Gualberto. Todos os direitos reservados.**
