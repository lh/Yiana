# Local LLM Options for Address Extraction

**Date**: November 1, 2025
**Purpose**: Evaluate local LLMs for enhancing address extraction
**Context**: Phase 4 of Address Extraction Improvement Plan

---

## Requirements

### Must Have
- ✅ **Runs locally** (privacy - medical data)
- ✅ **Fast inference** (<2 seconds per page on Mac mini)
- ✅ **Good at structured extraction** (JSON output)
- ✅ **Reasonable memory footprint** (< 8GB RAM)
- ✅ **macOS compatible** (runs on devon - Mac mini)

### Nice to Have
- ✅ **Fine-tunable** (can train on our correction data)
- ✅ **Function calling** (structured output via tools)
- ✅ **Good with medical text** (or fine-tunable for it)
- ✅ **Active development** (ongoing improvements)

---

## Recommended Options

### Option 1: Qwen2.5-3B (RECOMMENDED)

**Pros**:
- ✅ **Excellent structured output** - Best function calling in small models
- ✅ **Fast** - 3B params = ~2GB RAM, very fast inference
- ✅ **Strong multilingual** - Handles UK addresses, medical terminology
- ✅ **Active development** - Qwen team regularly updates
- ✅ **Already in AddressExtractor** - Currently using `qwen2.5:3b` via Ollama

**Cons**:
- ⚠️ Smaller context window (4K tokens) - but enough for single page

**Use Case**: Primary choice for production. Fast enough to run on every extraction.

**Setup**:
```bash
# Already available via Ollama
ollama pull qwen2.5:3b

# Or larger variant for better accuracy
ollama pull qwen2.5:7b  # 4GB RAM
```

**Example Prompt**:
```python
prompt = """Extract patient and GP information from this medical letter.
Return JSON with these fields:
- full_name: Patient's full name
- date_of_birth: In DD/MM/YYYY format
- address_line_1, address_line_2, city, county, postcode
- gp_name, gp_practice, gp_address, gp_postcode

Letter text:
{ocr_text}

JSON output:"""
```

**Performance Estimate**:
- Inference: ~1-2 seconds per page (Mac mini M1/M2)
- Memory: ~2.5GB RAM
- Accuracy: ~80-85% on medical letters (before fine-tuning)

---

### Option 2: Llama 3.2-3B

**Pros**:
- ✅ **Meta's latest small model** - Good general performance
- ✅ **Fast** - Similar speed to Qwen2.5-3B
- ✅ **Strong instruction following**
- ✅ **Good JSON output** (with proper prompting)

**Cons**:
- ⚠️ Less structured than Qwen for extraction tasks
- ⚠️ Meta license (commercial use OK but restricted)

**Use Case**: Alternative to Qwen if better at specific patterns

**Setup**:
```bash
ollama pull llama3.2:3b
```

---

### Option 3: Phi-3.5-mini (3.8B)

**Pros**:
- ✅ **Microsoft's specialized model** - Trained for reasoning
- ✅ **Excellent structured output**
- ✅ **Small but capable** - Punches above weight class
- ✅ **MIT license** - Fully open

**Cons**:
- ⚠️ Slightly larger than 3B models
- ⚠️ Can be verbose (needs prompt tuning)

**Use Case**: Good for complex/ambiguous cases

**Setup**:
```bash
ollama pull phi3.5:3.8b
```

---

### Option 4: Mistral-7B (Fallback for Hard Cases)

**Pros**:
- ✅ **Stronger reasoning** - Better for ambiguous addresses
- ✅ **Good with medical text**
- ✅ **Sliding window attention** - Better context handling

**Cons**:
- ⚠️ Slower (~4-5 seconds per page)
- ⚠️ More memory (5GB RAM)

**Use Case**: Fallback when smaller models have low confidence

**Setup**:
```bash
ollama pull mistral:7b
```

---

## Fine-Tuning Options

### Approach 1: LoRA Fine-Tuning (RECOMMENDED)

Fine-tune on your correction data to improve accuracy on YOUR specific letter formats.

**What is LoRA?**
- Low-Rank Adaptation: Efficient fine-tuning technique
- Only trains small adapter layers (~10MB)
- Fast training (minutes on MacBook)
- Keeps base model intact

**Requirements**:
- 20+ corrected examples (we'll have this after Phase 2)
- MLX or llama.cpp for training (both support Mac)

**Expected Improvement**:
- Before fine-tuning: 80% accuracy
- After fine-tuning: 90-95% accuracy (on similar letters)

**Training Time**:
- Qwen2.5-3B: ~5-10 minutes on Mac mini (M1/M2)
- 100 training examples

**Setup** (using MLX on macOS):
```bash
pip install mlx-lm

# Prepare training data
python prepare_training_data.py  # Export corrections as JSONL

# Fine-tune
mlx_lm.lora \
    --model Qwen/Qwen2.5-3B \
    --train training_data.jsonl \
    --iters 100 \
    --save-every 20

# Merge LoRA adapter
mlx_lm.fuse \
    --model Qwen/Qwen2.5-3B \
    --adapter-file adapters.npz \
    --save-path yiana-address-extractor
```

---

### Approach 2: Full Fine-Tuning (Advanced)

Only if LoRA doesn't give enough improvement.

**Pros**:
- Maximum customization
- Can change model behavior significantly

**Cons**:
- Slower training (hours)
- Requires more data (100+ examples)
- Larger storage (full model copy)

---

## Hybrid Strategy (RECOMMENDED)

Use different models for different confidence levels:

```python
def extract_address(ocr_text, page_num):
    # 1. Try pattern-based (fast, deterministic)
    pattern_result = pattern_extractor.extract(ocr_text)

    if pattern_result and pattern_result['confidence'] > 0.8:
        return pattern_result  # High confidence, use it

    # 2. Try Qwen2.5-3B (fast LLM)
    llm_result = qwen_extractor.extract(ocr_text)

    if llm_result and llm_result['confidence'] > 0.7:
        return llm_result

    # 3. Fallback to Mistral-7B for hard cases
    if pattern_result or llm_result:  # Something found, but low confidence
        mistral_result = mistral_extractor.extract(ocr_text)
        return mistral_result

    # 4. Nothing found
    return None
```

**Performance Breakdown** (estimated):
- 60% of pages: Pattern-based only (~0.1s)
- 30% of pages: Qwen2.5-3B (~1.5s)
- 10% of pages: Mistral-7B (~4s)
- **Average**: ~0.7s per page

---

## Comparison Matrix

| Model | Size | Speed | Accuracy* | Memory | License | Recommended For |
|-------|------|-------|-----------|--------|---------|-----------------|
| **Qwen2.5-3B** | 3B | ⚡⚡⚡ | ★★★★ | 2.5GB | Apache 2.0 | **Primary choice** |
| Llama 3.2-3B | 3B | ⚡⚡⚡ | ★★★ | 2.5GB | Meta | Alternative |
| Phi-3.5-mini | 3.8B | ⚡⚡ | ★★★★ | 3GB | MIT | Complex cases |
| Mistral-7B | 7B | ⚡ | ★★★★★ | 5GB | Apache 2.0 | Hard cases only |

*Accuracy before fine-tuning on medical letters

---

## Implementation Timeline

### Week 1-2: Baseline LLM
- ✅ Qwen2.5-3B already available in `llm_extractor.py`
- ⬜ Test on current documents
- ⬜ Measure accuracy vs pattern-based

### Week 3-4: Collect Training Data
- ⬜ Implement Phase 2 (user editing)
- ⬜ Collect 20+ corrections
- ⬜ Export as training data

### Week 5-6: Fine-Tuning
- ⬜ Set up MLX on Mac mini
- ⬜ Train LoRA adapter on corrections
- ⬜ A/B test fine-tuned vs base model

### Week 7-8: Hybrid System
- ⬜ Implement confidence-based routing
- ⬜ Deploy to devon for automatic extraction
- ⬜ Monitor accuracy and speed

---

## Recommended Path Forward

### Phase 1 (Now - Quick Win)
Use **Qwen2.5-3B** (already integrated) for low-confidence pattern matches:
```python
if pattern_confidence < 0.5:
    use_llm = True
```

### Phase 2 (After 20 corrections)
**Fine-tune Qwen2.5-3B** with LoRA on your medical letters:
- Expected improvement: 80% → 90-95% accuracy
- Training time: 10 minutes
- Deployment: Replace base model with fine-tuned version

### Phase 3 (After 100 corrections)
Add **Mistral-7B fallback** for hard cases:
- Slow but accurate
- Only used for ambiguous extractions (~10% of cases)

### Phase 4 (Optional)
Experiment with **model ensembling**:
- Run both Qwen and Mistral
- Use confidence voting to pick best result

---

## Tools & Infrastructure

### Ollama (Current)
Already using Ollama for easy model management.

**Pros**: Simple, works well
**Cons**: Less control over fine-tuning

### MLX (For Fine-Tuning)
Apple's ML framework, optimized for Apple Silicon.

**Pros**: Fast on Mac, native support
**Cons**: macOS only

**Install**:
```bash
pip install mlx mlx-lm
```

### llama.cpp (Alternative)
Cross-platform inference engine.

**Pros**: Very fast, quantized models
**Cons**: More complex setup

---

## Cost Analysis

### Development Time
- Integration: 2-3 days (already done for Qwen)
- Fine-tuning setup: 1 day
- Training: 10 minutes per iteration
- Testing: 1 week per model

### Runtime Cost
- **Local inference**: FREE (electricity only)
- **No API costs** (vs GPT-4: $0.03 per page = $30 per 1000 pages)
- **Privacy**: Medical data never leaves your network

### Storage
- Base model: 2-4GB per model
- Fine-tuned adapters: 10-50MB each
- Total: <10GB for full hybrid system

---

## Privacy & Security

### Local Processing ✅
- All models run on devon (Mac mini)
- No internet required for inference
- Medical data never sent to cloud

### Data Protection ✅
- Training data stored in iCloud with iOS Data Protection
- Fine-tuned models stay on local machines
- GDPR/HIPAA compliant (data never leaves your control)

---

## Recommendations Summary

1. **Start with Qwen2.5-3B** - Already integrated, fast, good accuracy
2. **Collect 20+ corrections** - Build training dataset (Phase 2)
3. **Fine-tune with LoRA** - 10-minute training, big accuracy boost
4. **Add Mistral-7B fallback** - For hard cases only
5. **Monitor & iterate** - Continuous improvement based on usage

**Bottom Line**: Qwen2.5-3B fine-tuned on your letters should give 90%+ accuracy while staying fast and private.

---

## Related Documentation

- **AddressExtractionImprovementPlan.md**: Overall improvement strategy
- **llm_extractor.py**: Current LLM integration code
- **training_analysis.py**: Script for analyzing corrections

---

## References

- Qwen2.5: https://github.com/QwenLM/Qwen2.5
- MLX: https://github.com/ml-explore/mlx
- Ollama: https://ollama.ai
- LoRA paper: https://arxiv.org/abs/2106.09685
