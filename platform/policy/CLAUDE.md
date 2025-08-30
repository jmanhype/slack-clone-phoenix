# Platform Policy Directory

## Purpose
Platform policies and verification gates for quality assurance.

## Allowed Operations
- ✅ Read policy configurations
- ✅ Update verification thresholds
- ✅ Add new policy rules
- ✅ Test policy enforcement
- ⚠️ Modify critical policies with approval
- ❌ Disable safety verification gates

## Policy Files

### verify.json
- Verification gate configuration
- Truth score thresholds (≥ 0.95)
- Quality metrics requirements
- Test coverage minimums
- Performance benchmarks

## Primary Agents
- `production-validator` - Policy enforcement
- `tester` - Quality validation
- `system-architect` - Policy design
- `reviewer` - Policy review and updates

## Verification Gates
- **Truth Score** - Minimum 0.95 for production
- **Test Coverage** - Minimum 80% code coverage
- **Performance** - Response time thresholds
- **Security** - Vulnerability scanning
- **Documentation** - Required documentation completeness

## Policy Structure
```json
{
  "gates": {
    "truth_score": {
      "minimum": 0.95,
      "required": true
    },
    "test_coverage": {
      "minimum": 0.80,
      "required": true
    }
  }
}
```

## Gate Enforcement
Policies are enforced at:
- Experiment creation
- Code commits
- Pipeline execution
- Production deployment
- Quality reviews

## Policy Testing
```bash
# Test policy enforcement
npx tsx scripts/verify.ts --policy-check
./claude/hooks/verify_gate.sh --test
```

## Configuration Options
- `strict_mode` - Fail on any policy violation
- `warning_mode` - Log violations but continue
- `grace_period` - Temporary policy relaxation
- `exemptions` - Specific experiment exemptions

## Best Practices
1. Keep policies realistic and achievable
2. Test policy changes before deployment
3. Document policy rationale
4. Regular policy review and updates
5. Balance quality with development velocity
