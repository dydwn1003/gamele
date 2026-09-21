import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Joystick } from '../components/Joystick';
import { HeroSprite } from '../components/sprites/HeroSprite';
import { MonsterSprite } from '../components/sprites/MonsterSprite';
import { chapterForStage, paletteForChapter } from '../components/sprites/palette';
import { rollDamage } from '../game/combat';
import {
  ATTACK_COOLDOWN_MS,
  ATTACK_RANGE,
  clamp,
  DAMAGE_POPUP_MS,
  DEATH_ANIM_MS,
  distance,
  ENTITY_RADIUS,
  FIELD_HEIGHT,
  FIELD_WIDTH,
  HERO_STUN_MS,
  HIT_FLASH_MS,
  KILLS_PER_STAGE,
  LUNGE_MS,
  MONSTER_ATTACK_COOLDOWN_MS,
  MONSTER_ATTACK_RANGE,
  MONSTER_COUNT,
  PLAYER_SPEED,
  randomFieldPoint,
  RESPAWN_DELAY_MS,
  TICK_MS,
  wanderVelocity,
} from '../game/field';
import { CLASS_SKILLS, SkillConfig, skillPowerMultiplier } from '../game/skills';
import { getStage } from '../game/stages';
import { StatBlock } from '../game/types';
import { totalStats } from '../game/hero';
import { EquipmentItem } from '../game/types';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

interface ActiveBuff {
  stat: keyof StatBlock;
  multiplier: number;
  until: number;
}

function applyBuff(stats: StatBlock, buff: ActiveBuff | null, now: number): StatBlock {
  if (!buff || now >= buff.until) return stats;
  return { ...stats, [buff.stat]: stats[buff.stat] * buff.multiplier };
}

interface MonsterEntity {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  hitUntil: number;
  diedAt: number | null;
  lastAttackAt: number;
}

interface DamagePopup {
  id: number;
  x: number;
  y: number;
  value: number;
  isCrit: boolean;
  createdAt: number;
}

interface HeroAttackFx {
  at: number;
  angle: number;
}

interface WorldState {
  heroX: number;
  heroY: number;
  heroHp: number;
  heroMaxHp: number;
  heroLastAttackAt: number;
  heroAttack: HeroAttackFx | null;
  stunnedUntil: number;
  monsters: MonsterEntity[];
  killCount: number;
  damagePopups: DamagePopup[];
  skillCooldownUntil: Record<string, number>;
  buff: ActiveBuff | null;
}

function spawnMonster(id: number, maxHp: number): MonsterEntity {
  const p = randomFieldPoint();
  return {
    id,
    x: p.x,
    y: p.y,
    vx: PLAYER_SPEED * 0.3,
    vy: 0,
    hp: maxHp,
    maxHp,
    alive: true,
    hitUntil: 0,
    diedAt: null,
    lastAttackAt: 0,
  };
}

function spawnAllMonsters(maxHp: number): MonsterEntity[] {
  return Array.from({ length: MONSTER_COUNT }, (_, i) => spawnMonster(i, maxHp));
}

function buildInitialWorld(heroMaxHp: number, monsterMaxHp: number): WorldState {
  return {
    heroX: FIELD_WIDTH / 2,
    heroY: FIELD_HEIGHT - ENTITY_RADIUS * 2,
    heroHp: heroMaxHp,
    heroMaxHp,
    heroLastAttackAt: 0,
    heroAttack: null,
    stunnedUntil: 0,
    monsters: spawnAllMonsters(monsterMaxHp),
    killCount: 0,
    damagePopups: [],
    skillCooldownUntil: {},
    buff: null,
  };
}

let popupIdCounter = 0;

export function FieldScreen() {
  const equipped = useGameStore((s) => s.equipped);
  const heroLevel = useGameStore((s) => s.heroLevel);
  const currentStage = useGameStore((s) => s.currentStage);
  const classId = useGameStore((s) => s.classId) ?? 'warrior';
  const allocatedStats = useGameStore((s) => s.allocatedStats);
  const skillLevelsSelector = useGameStore((s) => s.skillLevels);

  const initialStage = getStage(currentStage);
  const initialEquippedList = Object.values(equipped).filter(
    (i): i is EquipmentItem => i !== null
  );
  const initialHeroStats = totalStats(classId, heroLevel, allocatedStats, initialEquippedList);

  const worldRef = useRef<WorldState | null>(null);
  const [world, setWorld] = useState<WorldState>(() => {
    const w = buildInitialWorld(initialHeroStats.hp, initialStage.enemyStats.hp);
    worldRef.current = w;
    return w;
  });

  const joystickDirRef = useRef({ x: 0, y: 0 });
  const autoHuntRef = useRef(false);
  const [autoHunt, setAutoHunt] = useState(false);
  const skillRequestRef = useRef<string | null>(null);
  const lastTsRef = useRef(Date.now());

  const toggleAutoHunt = () => {
    autoHuntRef.current = !autoHuntRef.current;
    setAutoHunt(autoHuntRef.current);
  };

  const requestSkill = (skillId: string) => {
    skillRequestRef.current = skillId;
  };

  useEffect(() => {
    const id = setInterval(() => {
      const now = Date.now();
      const dt = Math.min(0.12, (now - lastTsRef.current) / 1000);
      lastTsRef.current = now;

      const s = useGameStore.getState();
      const activeClassId = s.classId ?? 'warrior';
      const equippedList = Object.values(s.equipped).filter(
        (i): i is EquipmentItem => i !== null
      );
      const baseHeroStats = totalStats(activeClassId, s.heroLevel, s.allocatedStats, equippedList);
      const skills = CLASS_SKILLS[activeClassId].filter((sk) => (s.skillLevels[sk.id] ?? 0) >= 1);
      const skillLevels = s.skillLevels;
      const stage = getStage(s.currentStage);
      const monsterStats: StatBlock = stage.enemyStats;
      const perKillGold = Math.max(1, Math.round(stage.goldReward / KILLS_PER_STAGE));
      const perKillExp = Math.max(1, Math.round(stage.expReward / KILLS_PER_STAGE));

      const prev = worldRef.current;
      if (!prev) return;
      let { heroX, heroY, heroHp, stunnedUntil, killCount, heroLastAttackAt } = prev;
      let heroAttack = prev.heroAttack;
      let monsters = prev.monsters;
      let damagePopups = prev.damagePopups.filter((p) => now - p.createdAt < DAMAGE_POPUP_MS);
      const skillCooldownUntil = { ...prev.skillCooldownUntil };

      // heal to full whenever max HP changes (level up / gear change)
      let heroMaxHp = baseHeroStats.hp;
      if (heroMaxHp !== prev.heroMaxHp) heroHp = heroMaxHp;

      const stunned = now < stunnedUntil;
      const buff = prev.buff && now < prev.buff.until ? prev.buff : null;
      const heroStats = applyBuff(baseHeroStats, buff, now);

      // --- movement ---
      let moveX = 0;
      let moveY = 0;
      if (!stunned) {
        if (autoHuntRef.current) {
          const alive = monsters.filter((m) => m.alive);
          const target = alive.reduce<MonsterEntity | null>((closest, m) => {
            const d = distance(heroX, heroY, m.x, m.y);
            const cd = closest ? distance(heroX, heroY, closest.x, closest.y) : Infinity;
            return d < cd ? m : closest;
          }, null);
          if (target) {
            const d = distance(heroX, heroY, target.x, target.y);
            if (d > ATTACK_RANGE * 0.7) {
              moveX = (target.x - heroX) / d;
              moveY = (target.y - heroY) / d;
            }
          }
        } else {
          moveX = joystickDirRef.current.x;
          moveY = joystickDirRef.current.y;
        }
      }
      const moveLen = Math.hypot(moveX, moveY);
      if (moveLen > 0.05) {
        heroX = clamp(
          heroX + (moveX / moveLen) * PLAYER_SPEED * dt,
          ENTITY_RADIUS,
          FIELD_WIDTH - ENTITY_RADIUS
        );
        heroY = clamp(
          heroY + (moveY / moveLen) * PLAYER_SPEED * dt,
          ENTITY_RADIUS,
          FIELD_HEIGHT - ENTITY_RADIUS
        );
      }

      // --- monster AI: wander, bounce, attack hero ---
      let goldGained = 0;
      let expGained = 0;
      monsters = monsters.map((m) => {
        if (!m.alive) {
          if (m.diedAt !== null && now - m.diedAt > RESPAWN_DELAY_MS) {
            return spawnMonster(m.id, stage.enemyStats.hp);
          }
          return m;
        }

        let { x, y, vx, vy, lastAttackAt, hp } = m;
        if (Math.random() < 0.02) {
          const w = wanderVelocity(vx || 1, vy || 0);
          vx = w.vx;
          vy = w.vy;
        }
        x += vx * dt;
        y += vy * dt;
        if (x <= ENTITY_RADIUS || x >= FIELD_WIDTH - ENTITY_RADIUS) vx = -vx;
        if (y <= ENTITY_RADIUS || y >= FIELD_HEIGHT - ENTITY_RADIUS) vy = -vy;
        x = clamp(x, ENTITY_RADIUS, FIELD_WIDTH - ENTITY_RADIUS);
        y = clamp(y, ENTITY_RADIUS, FIELD_HEIGHT - ENTITY_RADIUS);

        if (!stunned && distance(x, y, heroX, heroY) < MONSTER_ATTACK_RANGE) {
          if (now - lastAttackAt > MONSTER_ATTACK_COOLDOWN_MS) {
            const roll = rollDamage(monsterStats, heroStats);
            heroHp = Math.max(0, heroHp - roll.damage);
            lastAttackAt = now;
          }
        }

        return { ...m, x, y, vx, vy, lastAttackAt, hp };
      });

      if (heroHp <= 0 && !stunned) {
        stunnedUntil = now + HERO_STUN_MS;
        heroHp = Math.round(heroMaxHp * 0.5);
      }

      // --- hero basic attack: auto-fires on nearest target in range ---
      if (!stunned && now - heroLastAttackAt > ATTACK_COOLDOWN_MS) {
        const alive = monsters.filter((m) => m.alive);
        const target = alive.find((m) => distance(heroX, heroY, m.x, m.y) < ATTACK_RANGE);
        if (target) {
          const roll = rollDamage(heroStats, monsterStats);
          heroLastAttackAt = now;
          heroAttack = { at: now, angle: Math.atan2(target.y - heroY, target.x - heroX) };
          monsters = monsters.map((m) => (m.id === target.id ? { ...m, hp: m.hp - roll.damage, hitUntil: now + HIT_FLASH_MS } : m));
          damagePopups = [
            ...damagePopups,
            { id: ++popupIdCounter, x: target.x, y: target.y - ENTITY_RADIUS, value: roll.damage, isCrit: roll.isCrit, createdAt: now },
          ];
        }
      }

      // --- skill request ---
      const requestedSkill = skillRequestRef.current;
      skillRequestRef.current = null;
      const wantsAutoSkill = autoHuntRef.current;
      let nextBuff = buff;
      for (const skill of skills) {
        const ready = now >= (skillCooldownUntil[skill.id] ?? 0);
        const shouldTry = requestedSkill === skill.id || (wantsAutoSkill && ready);
        if (!ready || !shouldTry || stunned) continue;

        const alive = monsters.filter((m) => m.alive);
        const skillMult = skillPowerMultiplier(skill, skillLevels[skill.id] ?? 0);
        if (skill.kind === 'buff') {
          skillCooldownUntil[skill.id] = now + skill.cooldownMs;
          nextBuff = {
            stat: skill.buffStat ?? 'atk',
            multiplier: skill.buffMultiplier ?? 1,
            until: now + (skill.durationMs ?? 4000),
          };
          heroAttack = { at: now, angle: 0 };
        } else if (skill.kind === 'aoe') {
          const hits = alive.filter((m) => distance(heroX, heroY, m.x, m.y) < skill.range);
          if (hits.length === 0 && requestedSkill !== skill.id) continue;
          skillCooldownUntil[skill.id] = now + skill.cooldownMs;
          heroAttack = { at: now, angle: 0 };
          monsters = monsters.map((m) => {
            if (!hits.find((h) => h.id === m.id)) return m;
            const roll = rollDamage(heroStats, monsterStats, skillMult);
            damagePopups.push({
              id: ++popupIdCounter,
              x: m.x,
              y: m.y - ENTITY_RADIUS,
              value: roll.damage,
              isCrit: roll.isCrit,
              createdAt: now,
            });
            return { ...m, hp: m.hp - roll.damage, hitUntil: now + HIT_FLASH_MS };
          });
        } else {
          const target = alive.reduce<MonsterEntity | null>((closest, m) => {
            const d = distance(heroX, heroY, m.x, m.y);
            const cd = closest ? distance(heroX, heroY, closest.x, closest.y) : Infinity;
            return d < cd ? m : closest;
          }, null);
          if (!target || distance(heroX, heroY, target.x, target.y) > skill.range) continue;
          skillCooldownUntil[skill.id] = now + skill.cooldownMs;
          const roll = rollDamage(heroStats, monsterStats, skillMult);
          heroAttack = { at: now, angle: Math.atan2(target.y - heroY, target.x - heroX) };
          damagePopups.push({
            id: ++popupIdCounter,
            x: target.x,
            y: target.y - ENTITY_RADIUS,
            value: roll.damage,
            isCrit: roll.isCrit,
            createdAt: now,
          });
          monsters = monsters.map((m) =>
            m.id === target.id ? { ...m, hp: m.hp - roll.damage, hitUntil: now + HIT_FLASH_MS } : m
          );
        }
      }

      // --- resolve deaths ---
      monsters = monsters.map((m) => {
        if (m.alive && m.hp <= 0) {
          goldGained += perKillGold;
          expGained += perKillExp;
          killCount += 1;
          return { ...m, alive: false, hp: 0, diedAt: now };
        }
        return m;
      });

      if (goldGained > 0 || expGained > 0) {
        useGameStore.getState().gainKillReward(goldGained, expGained);
      }

      let finalKillCount = killCount;
      if (finalKillCount >= KILLS_PER_STAGE) {
        const before = useGameStore.getState().currentStage;
        useGameStore.getState().advanceStage();
        const after = useGameStore.getState().currentStage;
        finalKillCount = 0;
        if (after !== before) {
          const newStage = getStage(after);
          monsters = spawnAllMonsters(newStage.enemyStats.hp);
        }
      }

      const next: WorldState = {
        heroX,
        heroY,
        heroHp,
        heroMaxHp,
        heroLastAttackAt,
        heroAttack,
        stunnedUntil,
        monsters,
        killCount: finalKillCount,
        damagePopups,
        buff: nextBuff,
        skillCooldownUntil,
      };
      worldRef.current = next;
      setWorld(next);
    }, TICK_MS);

    return () => clearInterval(id);
  }, []);

  const now = Date.now();
  const stage = getStage(currentStage);
  const palette = paletteForChapter(chapterForStage(stage.id));
  const stunned = now < world.stunnedUntil;
  const activeBuff = world.buff && now < world.buff.until ? world.buff : null;
  const skills = CLASS_SKILLS[classId].filter((sk) => (skillLevelsSelector[sk.id] ?? 0) >= 1);

  const lungeElapsed = world.heroAttack ? now - world.heroAttack.at : Infinity;
  const lungeProgress = lungeElapsed < LUNGE_MS ? Math.sin((lungeElapsed / LUNGE_MS) * Math.PI) : 0;
  const lungeAngle = world.heroAttack?.angle ?? 0;
  const heroOffsetX = Math.cos(lungeAngle) * lungeProgress * 12;
  const heroOffsetY = Math.sin(lungeAngle) * lungeProgress * 12;

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.stageLabel}>{stage.name} · {stage.enemyName}</Text>
        <Text style={styles.killCount}>
          처치 {world.killCount} / {KILLS_PER_STAGE}
        </Text>
      </View>

      <View style={styles.hpBarTrack}>
        <View
          style={[
            styles.hpBarFill,
            { width: `${Math.max(0, (world.heroHp / world.heroMaxHp) * 100)}%` },
          ]}
        />
        <Text style={styles.hpBarText}>
          HP {Math.max(0, world.heroHp)} / {world.heroMaxHp}
        </Text>
      </View>

      <View style={[styles.field, { width: FIELD_WIDTH, height: FIELD_HEIGHT }]}>
        <LinearGradient
          colors={[palette.glow, colors.background]}
          style={StyleSheet.absoluteFill}
        />

        {world.monsters.map((m) => {
          const alive = m.alive;
          const deathElapsed = m.diedAt !== null ? now - m.diedAt : 0;
          const deathProgress = alive ? 0 : Math.min(1, deathElapsed / DEATH_ANIM_MS);
          if (!alive && deathProgress >= 1) return null;
          const hitActive = now < m.hitUntil;
          return (
            <View
              key={m.id}
              style={{
                position: 'absolute',
                left: m.x - ENTITY_RADIUS,
                top: m.y - ENTITY_RADIUS,
                opacity: alive ? 1 : 1 - deathProgress,
                transform: [{ scale: alive ? 1 : 1 - deathProgress * 0.6 }],
              }}
            >
              <View style={styles.shadow} />
              {alive && (
                <View style={styles.monsterHpTrack}>
                  <View
                    style={[styles.monsterHpFill, { width: `${(m.hp / m.maxHp) * 100}%` }]}
                  />
                </View>
              )}
              <MonsterSprite stageId={stage.id} size={ENTITY_RADIUS * 2} />
              {hitActive && <View style={styles.hitFlash} />}
            </View>
          );
        })}

        <View
          style={{
            position: 'absolute',
            left: world.heroX - ENTITY_RADIUS + heroOffsetX,
            top: world.heroY - ENTITY_RADIUS + heroOffsetY,
            opacity: stunned ? 0.5 : 1,
          }}
        >
          <View style={styles.shadow} />
          {activeBuff && <View style={styles.buffGlow} />}
          <HeroSprite classId={classId} size={ENTITY_RADIUS * 2} />
          {stunned && <Text style={styles.stunLabel}>기절!</Text>}
        </View>

        {world.damagePopups.map((p) => {
          const age = now - p.createdAt;
          const t = Math.min(1, age / DAMAGE_POPUP_MS);
          return (
            <Text
              key={p.id}
              style={[
                styles.damagePopup,
                p.isCrit && styles.damagePopupCrit,
                {
                  left: p.x - 20,
                  top: p.y - t * 34,
                  opacity: 1 - t,
                },
              ]}
            >
              {p.isCrit ? `${p.value}!` : p.value}
            </Text>
          );
        })}
      </View>

      <View style={styles.controlsRow}>
        <Joystick onChange={(dir) => { joystickDirRef.current = dir; }} />

        <View style={styles.rightControls}>
          <TouchableOpacity
            style={[styles.autoButton, autoHunt && styles.autoButtonActive]}
            onPress={toggleAutoHunt}
          >
            <Text style={styles.autoButtonText}>{autoHunt ? '자동사냥 ON' : '자동사냥 OFF'}</Text>
          </TouchableOpacity>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.skillScroll}
            contentContainerStyle={styles.skillRow}
          >
            {skills.map((skill: SkillConfig) => {
              const cooldownUntil = world.skillCooldownUntil[skill.id] ?? 0;
              const remaining = Math.max(0, Math.ceil((cooldownUntil - now) / 1000));
              const ready = remaining <= 0;
              const level = skillLevelsSelector[skill.id] ?? 0;
              return (
                <TouchableOpacity
                  key={skill.id}
                  style={[styles.skillButton, !ready && styles.skillButtonCooldown]}
                  onPress={() => requestSkill(skill.id)}
                  disabled={!ready}
                >
                  <Text style={styles.skillIcon}>{skill.icon}</Text>
                  <Text style={styles.skillName}>{skill.name}</Text>
                  <Text style={styles.skillLevelText}>Lv{level}</Text>
                  {!ready && <Text style={styles.skillCooldownText}>{remaining}</Text>}
                </TouchableOpacity>
              );
            })}
            {skills.length === 0 && (
              <Text style={styles.noSkillText}>홈에서 스킬을 먼저 배워보세요</Text>
            )}
          </ScrollView>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 10 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  stageLabel: { color: colors.text, fontWeight: '800', fontSize: 15 },
  killCount: { color: colors.textMuted, fontSize: 12, fontWeight: '700' },
  hpBarTrack: {
    height: 20,
    borderRadius: 10,
    backgroundColor: colors.surfaceAlt,
    overflow: 'hidden',
    justifyContent: 'center',
  },
  hpBarFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    backgroundColor: colors.success,
  },
  hpBarText: {
    color: colors.text,
    fontSize: 11,
    fontWeight: '700',
    textAlign: 'center',
  },
  field: {
    alignSelf: 'center',
    borderRadius: 20,
    overflow: 'hidden',
    borderWidth: 2,
    borderColor: colors.surfaceAlt,
  },
  shadow: {
    position: 'absolute',
    bottom: 2,
    left: ENTITY_RADIUS * 0.35,
    width: ENTITY_RADIUS * 1.3,
    height: ENTITY_RADIUS * 0.5,
    borderRadius: 100,
    backgroundColor: '#00000055',
  },
  monsterHpTrack: {
    position: 'absolute',
    top: -8,
    left: 4,
    width: ENTITY_RADIUS * 2 - 8,
    height: 5,
    borderRadius: 3,
    backgroundColor: '#00000066',
    overflow: 'hidden',
  },
  monsterHpFill: { height: '100%', backgroundColor: colors.danger },
  hitFlash: {
    ...StyleSheet.absoluteFill,
    backgroundColor: '#ffffff',
    borderRadius: ENTITY_RADIUS,
    opacity: 0.55,
  },
  stunLabel: {
    position: 'absolute',
    top: -18,
    alignSelf: 'center',
    color: colors.danger,
    fontWeight: '800',
    fontSize: 11,
  },
  damagePopup: {
    position: 'absolute',
    width: 40,
    textAlign: 'center',
    color: colors.text,
    fontWeight: '800',
    fontSize: 13,
  },
  damagePopupCrit: { color: colors.gold, fontSize: 16 },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  rightControls: { alignItems: 'flex-end', gap: 8 },
  autoButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  autoButtonActive: { backgroundColor: colors.success },
  autoButtonText: { color: colors.text, fontWeight: '700', fontSize: 12 },
  skillScroll: { maxWidth: 230 },
  skillRow: { flexDirection: 'row', gap: 6 },
  skillButton: {
    width: 54,
    height: 54,
    borderRadius: 14,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  skillButtonCooldown: { backgroundColor: colors.surfaceAlt },
  skillIcon: { fontSize: 17 },
  skillName: { color: colors.text, fontSize: 8, fontWeight: '700', marginTop: 1 },
  skillLevelText: { color: colors.gold, fontSize: 7, fontWeight: '700' },
  skillCooldownText: {
    position: 'absolute',
    color: colors.text,
    fontWeight: '800',
    fontSize: 15,
  },
  noSkillText: { color: colors.textMuted, fontSize: 11, width: 150 },
  buffGlow: {
    position: 'absolute',
    top: -6,
    left: -6,
    right: -6,
    bottom: -6,
    borderRadius: ENTITY_RADIUS + 6,
    backgroundColor: colors.gold,
    opacity: 0.35,
  },
});
