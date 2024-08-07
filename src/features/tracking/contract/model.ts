import { z } from "zod";

export const LoginResult = z.object({
  IsAuthorised: z.boolean(),
  HasReward: z.boolean(),
  Reward: z.optional(z.number()),
  Message: z.string(),
});
export type LoginResult = z.infer<typeof LoginResult>;
