import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

export const emitDomainEvent = internalMutation({
  args: {
    aggregateType: v.string(),
    aggregateId: v.string(),
    eventType: v.string(),
    source: v.string(),
    idempotencyKey: v.optional(v.string()),
    actorUserId: v.optional(v.id("users")),
    payload: v.any(),
    occurredAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const idempotencyKey = args.idempotencyKey?.trim();
    if (idempotencyKey) {
      const existing = await ctx.db
        .query("domainEvents")
        .withIndex("by_idempotency", (q) =>
          q
            .eq("aggregateType", args.aggregateType)
            .eq("aggregateId", args.aggregateId)
            .eq("idempotencyKey", idempotencyKey),
        )
        .unique();
      if (existing) return existing._id;
    }

    return await ctx.db.insert("domainEvents", {
      aggregateType: args.aggregateType,
      aggregateId: args.aggregateId,
      eventType: args.eventType,
      source: args.source,
      idempotencyKey,
      actorUserId: args.actorUserId,
      payload: args.payload,
      occurredAt: args.occurredAt ?? now,
      createdAt: now,
    });
  },
});

export const getConsumerCheckpoint = internalQuery({
  args: {
    consumer: v.string(),
  },
  handler: async (ctx, { consumer }) => {
    return await ctx.db
      .query("eventConsumers")
      .withIndex("by_consumer", (q) => q.eq("consumer", consumer))
      .unique();
  },
});

export const upsertConsumerCheckpoint = internalMutation({
  args: {
    consumer: v.string(),
    lastEventId: v.optional(v.id("domainEvents")),
    lastSeenCreatedAt: v.number(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("eventConsumers")
      .withIndex("by_consumer", (q) => q.eq("consumer", args.consumer))
      .unique();

    if (existing) {
      await ctx.db.patch(existing._id, {
        lastEventId: args.lastEventId ?? existing.lastEventId,
        lastSeenCreatedAt: Math.max(
          args.lastSeenCreatedAt,
          existing.lastSeenCreatedAt,
        ),
        updatedAt: now,
      });
      return existing._id;
    }

    return await ctx.db.insert("eventConsumers", {
      consumer: args.consumer,
      lastEventId: args.lastEventId,
      lastSeenCreatedAt: args.lastSeenCreatedAt,
      updatedAt: now,
    });
  },
});
