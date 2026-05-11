-- =====================================================================
-- Fix : étendre le CHECK constraint de user_roles à tous les rôles métier
-- =====================================================================
-- Problème : la contrainte initiale (E1) n'autorisait que 'admin' et
-- 'lecteur'. L'UI propose 5 rôles (operateur, direction, responsable_qhse
-- en plus). L'upsert échouait silencieusement sur ces 3 rôles → l'utilisateur
-- était créé dans auth.users mais sans entrée dans user_roles → écran
-- "Compte non configuré" à la connexion.
-- =====================================================================

ALTER TABLE public.user_roles
  DROP CONSTRAINT IF EXISTS user_roles_role_check;

ALTER TABLE public.user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('admin', 'lecteur', 'operateur', 'direction', 'responsable_qhse'));

-- Mise à jour du commentaire de la fonction pour refléter tous les rôles
COMMENT ON FUNCTION public.current_user_role() IS
  'Retourne le rôle de l''utilisateur courant (admin | responsable_qhse | direction | operateur | lecteur | NULL si non authentifié).';

COMMENT ON COLUMN public.user_roles.role IS
  'admin | responsable_qhse | direction | operateur | lecteur';
